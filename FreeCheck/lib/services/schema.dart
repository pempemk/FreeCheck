// SQLite schema of the app database, created on first launch.
//
// Same tables as the original PostgreSQL design
// (legacy/migrations/001_init.sql), adapted to SQLite:
// - SERIAL           -> INTEGER PRIMARY KEY AUTOINCREMENT
// - DATE / TIMESTAMP -> TEXT (YYYY-MM-DD / ISO-8601 in UTC)
// - NUMERIC          -> REAL
// - BOOLEAN          -> INTEGER 0/1

/// Bump when the schema changes, and add the upgrade steps.
const schemaVersion = 1;

const schema = [
  '''
CREATE TABLE organizers (
  org_id INTEGER PRIMARY KEY AUTOINCREMENT,
  org_name VARCHAR(150) NOT NULL UNIQUE,
  contact_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  color CHAR(7) NOT NULL,           -- hex เช่น #FF5733
  rate NUMERIC(3,2) NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE projects (
  project_id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_name TEXT NOT NULL,
  org_id INTEGER NOT NULL REFERENCES organizers(org_id),
  start_date TEXT NOT NULL,
  deadline TEXT,
  wages REAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','pending','submitted','completed')),
  submitted_at TEXT,
  paid_at TEXT,
  note TEXT NOT NULL DEFAULT '',
  UNIQUE (project_name, org_id)
)''',
  '''
CREATE TABLE types (
  type_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
)''',
  '''
CREATE TABLE checklists (
  checklist_id INTEGER PRIMARY KEY AUTOINCREMENT,
  type_id INTEGER NOT NULL REFERENCES types(type_id),
  name TEXT NOT NULL
)''',
  '''
CREATE TABLE project_checklists (
  project_id INTEGER NOT NULL REFERENCES projects(project_id),
  checklist_id INTEGER NOT NULL REFERENCES checklists(checklist_id),
  completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
  PRIMARY KEY (project_id, checklist_id)
)''',
  '''
CREATE TABLE ratings (
  rating_id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL UNIQUE REFERENCES projects(project_id),
  org_id INTEGER NOT NULL REFERENCES organizers(org_id),
  score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5)
)''',
];
