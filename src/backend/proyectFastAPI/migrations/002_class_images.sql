CREATE TABLE IF NOT EXISTS Class_Content (
    class_name_fk VARCHAR(50) PRIMARY KEY
      REFERENCES Class(class_name) ON UPDATE CASCADE ON DELETE CASCADE,
    class_image BYTEA
);
