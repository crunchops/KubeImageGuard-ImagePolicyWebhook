import os
import logging
from flask import Flask, render_template, request, jsonify, redirect, url_for
from werkzeug.middleware.proxy_fix import ProxyFix

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "default-secret-key-for-development")
app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1, x_host=1)

# Import webhook functionality
from webhook import webhook_bp
app.register_blueprint(webhook_bp)

# Store recent logs in memory for display purposes
# This is a simple solution - in production, consider using a proper logging system
class LogHandler:
    def __init__(self, max_logs=100):
        self.logs = []
        self.max_logs = max_logs
    
    def add_log(self, log_entry):
        if len(self.logs) >= self.max_logs:
            self.logs.pop(0)
        self.logs.append(log_entry)
    
    def get_logs(self):
        return list(reversed(self.logs))  # Return newest first

log_handler = LogHandler()

# Routes for web interface
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/logs')
def logs():
    return render_template('logs.html', logs=log_handler.get_logs())

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
