#!/bin/sh

# Start Gunicorn with 4 workers
exec gunicorn --bind 0.0.0.0:5000 --workers 4 --reuse-port main:app