from datetime import time

from .errors import CatalogError, ErrorCode

SCHOOL_START_SECONDS = 9 * 60 * 60
SCHOOL_END_SECONDS = 15 * 60 * 60
DAY_SECONDS = 24 * 60 * 60


def validate_task_schedule(
    creator_role: str,
    task_start_hour: time | None,
    task_duration_minutes: int,
) -> None:
    """Valida el intervalo completo de la tarea respecto al horario escolar."""
    if task_duration_minutes is None or task_duration_minutes <= 0:
        raise CatalogError(ErrorCode.INVALID_REQUEST)
    if task_start_hour is None:
        if creator_role == "student":
            raise CatalogError(ErrorCode.STUDENT_TASK_OUTSIDE_SCHOOL_HOURS)
        return

    start_seconds = (
        task_start_hour.hour * 60 * 60
        + task_start_hour.minute * 60
        + task_start_hour.second
        + task_start_hour.microsecond / 1_000_000
    )
    end_seconds = start_seconds + task_duration_minutes * 60

    if creator_role == "staff":
        if start_seconds < SCHOOL_START_SECONDS or end_seconds > SCHOOL_END_SECONDS:
            raise CatalogError(ErrorCode.STAFF_TASK_OUTSIDE_SCHOOL_HOURS)
        return

    if creator_role in {"parent", "student"}:
        if start_seconds < SCHOOL_START_SECONDS:
            overlaps_school = end_seconds > SCHOOL_START_SECONDS
        elif start_seconds < SCHOOL_END_SECONDS:
            overlaps_school = True
        else:
            next_school_start = DAY_SECONDS + SCHOOL_START_SECONDS
            overlaps_school = end_seconds > next_school_start
        if overlaps_school:
            error_code = (
                ErrorCode.STUDENT_TASK_OUTSIDE_SCHOOL_HOURS
                if creator_role == "student"
                else ErrorCode.PARENT_TASK_DURING_SCHOOL_HOURS
            )
            raise CatalogError(error_code)
