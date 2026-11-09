"""Classroom photos used both before login and in classroom management."""
import base64

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..activity_content import decode_image


def class_image(db: Session, name: str) -> str | None:
    image = db.execute(text('SELECT class_image FROM Class_Content WHERE class_name_fk=:name'),
                       {'name': name}).scalar_one_or_none()
    return base64.b64encode(bytes(image)).decode() if image else None


def save_class_image(db: Session, name: str, image: str | None) -> None:
    db.execute(text('INSERT INTO Class_Content(class_name_fk,class_image) VALUES (:name,:image) '
                    'ON CONFLICT(class_name_fk) DO UPDATE SET class_image=EXCLUDED.class_image'),
               {'name': name, 'image': decode_image(image)})
