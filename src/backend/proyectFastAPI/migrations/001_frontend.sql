-- Additive extension. Run with python -m proyectFastAPI.migrate after the base schema.
CREATE TABLE IF NOT EXISTS Task_Content (
    task_id_fk INT PRIMARY KEY REFERENCES Tasks(task_id) ON DELETE CASCADE,
    task_image BYTEA
);
CREATE TABLE IF NOT EXISTS Step_Content (
    step_id_fk INT PRIMARY KEY REFERENCES Steps(step_id) ON DELETE CASCADE,
    step_title VARCHAR(100) NOT NULL,
    step_duration INT NOT NULL CHECK (step_duration > 0),
    step_required BOOLEAN NOT NULL DEFAULT TRUE,
    step_image BYTEA
);
CREATE TABLE IF NOT EXISTS Task_Progress (
    stud_usr_fk VARCHAR(50) REFERENCES Student(stud_usr) ON UPDATE CASCADE ON DELETE CASCADE,
    task_id_fk INT REFERENCES Tasks(task_id) ON DELETE CASCADE,
    task_date DATE NOT NULL,
    task_finished BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (stud_usr_fk, task_id_fk, task_date)
);
CREATE TABLE IF NOT EXISTS Step_Progress (
    stud_usr_fk VARCHAR(50) NOT NULL,
    task_id_fk INT NOT NULL,
    task_date DATE NOT NULL,
    step_id_fk INT REFERENCES Steps(step_id) ON DELETE CASCADE,
    step_finished BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (stud_usr_fk, task_id_fk, task_date, step_id_fk),
    FOREIGN KEY (stud_usr_fk, task_id_fk, task_date)
      REFERENCES Task_Progress(stud_usr_fk, task_id_fk, task_date) ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ix_student_agenda_date ON stud_task(stud_usr_fk, task_date);
CREATE INDEX IF NOT EXISTS ix_task_steps_order ON Steps(generic_task_id_fk, step_index);

-- Removing an assignment must also remove its progress. Other students and
-- other dates of the same task retain their own progress.
CREATE OR REPLACE FUNCTION clear_unassigned_progress() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM Task_Progress p WHERE p.stud_usr_fk = OLD.stud_usr_fk
      AND p.task_id_fk = OLD.task_id_fk AND p.task_date = OLD.task_date
      AND NOT EXISTS (SELECT 1 FROM stud_task a WHERE a.stud_usr_fk = p.stud_usr_fk
        AND a.task_id_fk = p.task_id_fk AND a.task_date = p.task_date);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_clear_unassigned_progress ON stud_task;
CREATE TRIGGER trg_clear_unassigned_progress AFTER DELETE ON stud_task
FOR EACH ROW EXECUTE FUNCTION clear_unassigned_progress();
