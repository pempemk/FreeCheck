// SQLite schema of the app database, created on first launch.
//
// Column types follow the project's table structure document. SQLite keeps
// the declared types but stores values as:
// - IDENTITY      -> INTEGER PRIMARY KEY AUTOINCREMENT
// - DATE          -> text YYYY-MM-DD
// - TIMESTAMP(0)  -> text YYYY-MM-DDTHH:MM:SSZ (UTC, whole seconds)
// - BOOLEAN       -> 0 / 1
// Lengths such as VARCHAR(200) are enforced by the controllers' validate.

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
  org_id INTEGER NOT NULL REFERENCES organizers(org_id),
  project_name VARCHAR(200) NOT NULL,
  start_date DATE NOT NULL,
  deadline DATE DEFAULT NULL,
  wages NUMERIC(12,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','pending','submitted','completed')),
  submitted_at TIMESTAMP(0) DEFAULT NULL,
  paid_at TIMESTAMP(0) DEFAULT NULL,
  note TEXT NOT NULL DEFAULT '',
  UNIQUE (project_name, org_id, start_date)
)''',
  '''
CREATE TABLE types (
  type_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(100) NOT NULL UNIQUE
)''',
  '''
CREATE TABLE checklists (
  checklist_id INTEGER PRIMARY KEY AUTOINCREMENT,
  type_id INTEGER NOT NULL REFERENCES types(type_id),
  name VARCHAR(255) NOT NULL
)''',
  '''
CREATE TABLE project_checklists (
  project_id INTEGER NOT NULL REFERENCES projects(project_id),
  checklist_id INTEGER NOT NULL REFERENCES checklists(checklist_id),
  -- FALSE is written as 0: older Android SQLite has no TRUE/FALSE keywords.
  completed BOOLEAN NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
  PRIMARY KEY (project_id, checklist_id)
)''',
  '''
CREATE TABLE ratings (
  rating_id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id INTEGER NOT NULL UNIQUE REFERENCES projects(project_id),
  org_id INTEGER NOT NULL REFERENCES organizers(org_id),
  score SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5)
)''',
];
