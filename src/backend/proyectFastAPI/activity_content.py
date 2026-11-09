"""Rich task content, stored separately from the existing base schema."""
import base64
import binascii
from datetime import date

from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator
from sqlalchemy import text
from sqlalchemy.orm import Session

from .errors import ErrorCode, raise_api_error
from .gestion_usuarios.users_mng_backend import _image_media_type

MAX_IMAGE_BYTES = 5 * 1024 * 1024


def decode_image(value: str | None) -> bytes | None:
    if value is None:
        return None
    try:
        image = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error):
        raise ValueError('Invalid image encoding')
    if len(image) > MAX_IMAGE_BYTES or _image_media_type(image) is None:
        raise ValueError('Invalid image or size')
    return image


class StepPayload(BaseModel):
    model_config = ConfigDict(extra='forbid')
    step_id: StrictInt | None = None
    step_title: str = Field(strict=True, min_length=1, max_length=100)
    step_description: str = Field(strict=True, min_length=1, max_length=5000)
    step_duration: StrictInt = Field(gt=0, le=1440)
    step_required: StrictBool = True
    step_image: str | None = Field(default=None, max_length=7_000_000)

    @field_validator('step_title', 'step_description')
    @classmethod
    def non_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError('Empty text')
        return value.strip()

    @field_validator('step_image')
    @classmethod
    def image_valid(cls, value: str | None) -> str | None:
        decode_image(value)
        return value


class ActivityFields(BaseModel):
    steps: list[StepPayload] | None = Field(default=None, max_length=100)
    task_image: str | None = Field(default=None, max_length=7_000_000)

    @field_validator('task_image')
    @classmethod
    def image_valid(cls, value: str | None) -> str | None:
        decode_image(value)
        return value


def has_content(payload: ActivityFields) -> bool:
    return bool({'steps', 'task_image'} & payload.model_fields_set)


def save_content(db: Session, task_id: int, payload: ActivityFields) -> None:
    """Caller owns the transaction, including task creation and assignments."""
    db.execute(text('SELECT task_id FROM Tasks WHERE task_id=:id FOR UPDATE'), {'id': task_id})
    if 'task_image' in payload.model_fields_set:
        db.execute(text('INSERT INTO Task_Content(task_id_fk,task_image) VALUES (:id,:image) '
                        'ON CONFLICT(task_id_fk) DO UPDATE SET task_image=EXCLUDED.task_image'),
                   {'id': task_id, 'image': decode_image(payload.task_image)})
    if payload.steps is None:
        return
    # Replacing instructions invalidates prior confirmations: the activity has changed.
    db.execute(text('DELETE FROM Task_Progress WHERE task_id_fk=:id'), {'id': task_id})
    db.execute(text('DELETE FROM Steps WHERE generic_task_id_fk=:id'), {'id': task_id})
    for index, step in enumerate(payload.steps):
        step_id = db.execute(text(
            'INSERT INTO Steps(step_description,step_finished,step_index,generic_task_id_fk) '
            'VALUES (:description,FALSE,:index,:id) RETURNING step_id'),
            {'description': step.step_description, 'index': index, 'id': task_id}).scalar_one()
        db.execute(text('INSERT INTO Step_Content(step_id_fk,step_title,step_duration,step_required,step_image) '
                        'VALUES (:id,:title,:duration,:required,:image)'),
                   {'id': step_id, 'title': step.step_title, 'duration': step.step_duration,
                    'required': step.step_required, 'image': decode_image(step.step_image)})


def task_content(db: Session, task_id: int, student: str | None = None,
                 task_date: date | None = None) -> dict:
    rows = db.execute(text(
        'SELECT s.step_id,s.step_description,s.step_index,c.step_title,c.step_duration,c.step_required,c.step_image '
        'FROM Steps s LEFT JOIN Step_Content c ON c.step_id_fk=s.step_id '
        'WHERE s.generic_task_id_fk=:id ORDER BY s.step_index,s.step_id'), {'id': task_id}).mappings().all()
    progress = {}
    completed = False
    if student is not None and task_date is not None:
        progress = dict(db.execute(text('SELECT step_id_fk,step_finished FROM Step_Progress '
            'WHERE stud_usr_fk=:student AND task_id_fk=:id AND task_date=:date'),
            {'student': student, 'id': task_id, 'date': task_date}).all())
        completed = bool(db.execute(text('SELECT task_finished FROM Task_Progress '
            'WHERE stud_usr_fk=:student AND task_id_fk=:id AND task_date=:date'),
            {'student': student, 'id': task_id, 'date': task_date}).scalar_one_or_none())
    image = db.execute(text('SELECT task_image FROM Task_Content WHERE task_id_fk=:id'), {'id': task_id}).scalar_one_or_none()
    return {'task_finished': completed, 'task_image': base64.b64encode(bytes(image)).decode() if image else None,
        'steps': [{'step_id': row['step_id'], 'step_title': row['step_title'] or f"Paso {row['step_index'] + 1}",
                   'step_description': row['step_description'], 'step_index': row['step_index'],
                   'step_duration': row['step_duration'] or 1,
                   'step_required': row['step_required'] is not False,
                   'step_finished': progress.get(row['step_id'], False),
                   'step_image': base64.b64encode(bytes(row['step_image'])).decode() if row['step_image'] else None}
                  for row in rows]}
