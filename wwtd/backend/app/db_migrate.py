import secrets

from sqlalchemy import text
from sqlalchemy.engine import Engine

from app.market_codes import _CODE_ALPHABET, _CODE_LENGTH


def _column_names(conn, table: str) -> set[str]:
    rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
    return {row[1] for row in rows}


def _table_exists(conn, table: str) -> bool:
    row = conn.execute(
        text("SELECT name FROM sqlite_master WHERE type='table' AND name=:name"),
        {"name": table},
    ).fetchone()
    return row is not None


def _gen_code(used: set[str]) -> str:
    for _ in range(64):
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))
        if code not in used:
            used.add(code)
            return code
    raise RuntimeError("Could not allocate join code")


def _migrate_legacy_markets(conn) -> None:
    if not _table_exists(conn, "markets"):
        return
    if _table_exists(conn, "rooms"):
        if conn.execute(text("SELECT COUNT(*) FROM rooms")).scalar():
            return

    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS rooms (
                id VARCHAR(36) PRIMARY KEY,
                join_code VARCHAR(8) NOT NULL UNIQUE,
                person_id INTEGER NOT NULL,
                created_by VARCHAR(36) NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
    )
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS questions (
                id VARCHAR(36) PRIMARY KEY,
                room_id VARCHAR(36) NOT NULL,
                question TEXT NOT NULL,
                created_by VARCHAR(36) NOT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'open',
                winning_side VARCHAR(8),
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
    )
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS room_members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (room_id, user_id)
            )
            """
        )
    )

    markets = conn.execute(
        text(
            "SELECT id, join_code, person_id, question, created_by, status, winning_side, created_at "
            "FROM markets ORDER BY created_at ASC"
        )
    ).fetchall()

    used_codes: set[str] = set()
    code_to_room: dict[str, str] = {}
    market_to_room: dict[str, str] = {}

    for mid, join_code, person_id, question, created_by, status, winning_side, created_at in markets:
        raw = (join_code or "").strip().upper()
        code = raw if raw and raw not in used_codes else _gen_code(used_codes)
        if code not in code_to_room:
            code_to_room[code] = mid
            conn.execute(
                text(
                    "INSERT INTO rooms (id, join_code, person_id, created_by, created_at) "
                    "VALUES (:id, :code, :pid, :uid, :at)"
                ),
                {"id": mid, "code": code, "pid": person_id, "uid": created_by, "at": created_at},
            )
        room_id = code_to_room[code]
        market_to_room[mid] = room_id
        conn.execute(
            text(
                "INSERT INTO questions (id, room_id, question, created_by, status, winning_side, created_at) "
                "VALUES (:id, :rid, :q, :uid, :st, :ws, :at)"
            ),
            {
                "id": mid,
                "rid": room_id,
                "q": question,
                "uid": created_by,
                "st": status,
                "ws": winning_side,
                "at": created_at,
            },
        )

    if _table_exists(conn, "market_members"):
        for market_id, user_id, joined_at in conn.execute(
            text("SELECT market_id, user_id, joined_at FROM market_members")
        ).fetchall():
            room_id = market_to_room.get(market_id, market_id)
            conn.execute(
                text(
                    "INSERT OR IGNORE INTO room_members (room_id, user_id, joined_at) "
                    "VALUES (:rid, :uid, :at)"
                ),
                {"rid": room_id, "uid": user_id, "at": joined_at},
            )

    if _table_exists(conn, "bets") and "market_id" in _column_names(conn, "bets"):
        conn.execute(text("ALTER TABLE bets RENAME TO bets_legacy"))
        conn.execute(
            text(
                """
                CREATE TABLE bets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    question_id VARCHAR(36) NOT NULL,
                    user_id VARCHAR(36) NOT NULL,
                    side VARCHAR(8) NOT NULL,
                    amount REAL NOT NULL,
                    payout_amount REAL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
        )
        conn.execute(
            text(
                "INSERT INTO bets (id, question_id, user_id, side, amount, payout_amount, created_at) "
                "SELECT id, market_id, user_id, side, amount, payout_amount, created_at FROM bets_legacy"
            )
        )
        conn.execute(text("DROP TABLE bets_legacy"))


def _migrate_profiles_auth_sqlite(conn) -> None:
    if not _table_exists(conn, "profiles"):
        return
    cols = _column_names(conn, "profiles")
    if "username" not in cols:
        conn.execute(text("ALTER TABLE profiles ADD COLUMN username VARCHAR(32)"))
    if "password_hash" not in cols:
        conn.execute(text("ALTER TABLE profiles ADD COLUMN password_hash VARCHAR(128)"))


def _migrate_room_member_balance_sqlite(conn) -> None:
    if not _table_exists(conn, "room_members"):
        return
    cols = _column_names(conn, "room_members")
    if "balance_points" not in cols:
        conn.execute(
            text("ALTER TABLE room_members ADD COLUMN balance_points REAL NOT NULL DEFAULT 500")
        )


def _migrate_room_people_sqlite(conn) -> None:
    if not _table_exists(conn, "rooms"):
        return
    cols = _column_names(conn, "rooms")
    if "room_type" not in cols:
        conn.execute(
            text("ALTER TABLE rooms ADD COLUMN room_type VARCHAR(16) NOT NULL DEFAULT 'individual'")
        )
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS room_people (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                room_id VARCHAR(36) NOT NULL,
                person_id INTEGER NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                is_primary BOOLEAN NOT NULL DEFAULT 0,
                UNIQUE (room_id, person_id)
            )
            """
        )
    )
    conn.execute(
        text(
            """
            INSERT OR IGNORE INTO room_people (room_id, person_id, sort_order, is_primary)
            SELECT id, person_id, 0, 1 FROM rooms
            """
        )
    )


def _migrate_question_targets_sqlite(conn) -> None:
    if not _table_exists(conn, "questions") or not _table_exists(conn, "rooms"):
        return
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS question_targets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                question_id VARCHAR(36) NOT NULL,
                person_id INTEGER NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                UNIQUE (question_id, person_id)
            )
            """
        )
    )
    conn.execute(
        text(
            """
            INSERT OR IGNORE INTO question_targets (question_id, person_id, sort_order)
            SELECT questions.id, rooms.person_id, 0
            FROM questions
            JOIN rooms ON questions.room_id = rooms.id
            """
        )
    )


def _migrate_room_member_balance_postgres(conn) -> None:
    conn.execute(
        text(
            "ALTER TABLE room_members ADD COLUMN IF NOT EXISTS "
            "balance_points DOUBLE PRECISION NOT NULL DEFAULT 500"
        )
    )


def _migrate_room_people_postgres(conn) -> None:
    conn.execute(
        text("ALTER TABLE rooms ADD COLUMN IF NOT EXISTS room_type VARCHAR(16) NOT NULL DEFAULT 'individual'")
    )
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS room_people (
                id SERIAL PRIMARY KEY,
                room_id VARCHAR(36) NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
                person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE RESTRICT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                is_primary BOOLEAN NOT NULL DEFAULT FALSE,
                UNIQUE (room_id, person_id)
            )
            """
        )
    )
    conn.execute(
        text(
            """
            INSERT INTO room_people (room_id, person_id, sort_order, is_primary)
            SELECT id, person_id, 0, TRUE FROM rooms
            ON CONFLICT (room_id, person_id) DO NOTHING
            """
        )
    )


def _migrate_question_targets_postgres(conn) -> None:
    conn.execute(
        text(
            """
            CREATE TABLE IF NOT EXISTS question_targets (
                id SERIAL PRIMARY KEY,
                question_id VARCHAR(36) NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
                person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE RESTRICT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                UNIQUE (question_id, person_id)
            )
            """
        )
    )
    conn.execute(
        text(
            """
            INSERT INTO question_targets (question_id, person_id, sort_order)
            SELECT questions.id, rooms.person_id, 0
            FROM questions
            JOIN rooms ON questions.room_id = rooms.id
            ON CONFLICT (question_id, person_id) DO NOTHING
            """
        )
    )


def _migrate_profiles_auth_postgres(conn) -> None:
    conn.execute(
        text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS username VARCHAR(32) UNIQUE")
    )
    conn.execute(
        text("ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash VARCHAR(128)")
    )


def run_migrations(engine: Engine) -> None:
    dialect = engine.dialect.name
    if dialect == "sqlite":
        with engine.begin() as conn:
            if _table_exists(conn, "profiles") and "balance_points" not in _column_names(
                conn, "profiles"
            ):
                conn.execute(
                    text("ALTER TABLE profiles ADD COLUMN balance_points REAL NOT NULL DEFAULT 500")
                )
            _migrate_profiles_auth_sqlite(conn)
            _migrate_room_member_balance_sqlite(conn)
            _migrate_legacy_markets(conn)
            _migrate_room_people_sqlite(conn)
            _migrate_question_targets_sqlite(conn)
    elif dialect == "postgresql":
        with engine.begin() as conn:
            _migrate_profiles_auth_postgres(conn)
            _migrate_room_member_balance_postgres(conn)
            _migrate_room_people_postgres(conn)
            _migrate_question_targets_postgres(conn)
