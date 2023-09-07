FROM python:3.10-alpine3.18 as builder

ENV POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_IN_PROJECT=1 \
  POETRY_VIRTUALENVS_CREATE=1 \
  POETRY_CACHE_DIR=/tmp/poetry_cache \
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_VERSION=1.5.1

RUN pip install "poetry==$POETRY_VERSION"
RUN apk add --update --no-cache gcc libc-dev
WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=$POETRY_CACHE_DIR poetry install --no-root --no-ansi

#----------------------------------------------------------------------------------------

FROM python:3.10-alpine3.18 as runtime
LABEL maintainer="Christopher LOUËT"

ENV VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

RUN apk add --update --no-cache bash \
    && rm -rf /var/cache/apk/*
RUN addgroup -g 1000 app \
    && adduser -G app -u 1000 app -D

USER app
WORKDIR /app
COPY --chown=app:app --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY --chown=app:app . /app/

CMD ["/bin/sh"]
