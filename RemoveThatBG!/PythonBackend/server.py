#!/usr/bin/env python3
from flask import Flask, request, send_file, jsonify
from rembg import remove, new_session
from PIL import Image
import io
import sys
import gc
import signal
import os
import logging
import tempfile
import shutil
from datetime import datetime
import socket
import json

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger(__name__)

# Cache for loaded models to avoid reloading
model_cache = {}

# Store temp files for cleanup
temp_files = []

def get_models_directory():
    """Get Application Support directory for models."""
    if sys.platform == 'darwin':  # macOS
        app_support = os.path.expanduser('~/Library/Application Support/RemoveThatBG/models')
    elif sys.platform == 'win32':  # Windows
        app_support = os.path.join(os.environ.get('APPDATA', ''), 'RemoveThatBG', 'models')
    else:  # Linux
        app_support = os.path.expanduser('~/.local/share/RemoveThatBG/models')
    
    os.makedirs(app_support, exist_ok=True)
    return app_support

def check_disk_space(path, required_mb=500):
    """Check if there's enough disk space available."""
    try:
        stat = os.statvfs(path)
        available_mb = (stat.f_bavail * stat.f_frsize) / (1024 * 1024)
        return available_mb >= required_mb
    except Exception as e:
        logger.warning(f"Could not check disk space: {e}")
        return True  # Assume OK if check fails

def get_session(model_name):
    """Load or retrieve cached model session."""
    models_dir = get_models_directory()
    
    # Check disk space before loading
    if not check_disk_space(models_dir):
        logger.error(f"Insufficient disk space in {models_dir}")
        raise RuntimeError("Insufficient disk space for model storage")
    
    # Set environment variable for rembg to use our custom path
    os.environ['U2NET_HOME'] = models_dir
    
    model_path = os.path.join(models_dir, f"{model_name}.onnx")
    
    if not os.path.exists(model_path):
        logger.info(f"Model {model_name} not found at {model_path}. Will be downloaded by rembg.")
    else:
        logger.info(f"Model {model_name} found at {model_path}.")
    
    if model_name not in model_cache:
        logger.info(f"Loading model: {model_name}...")
        model_cache[model_name] = new_session(model_name=model_name)
        logger.info(f"Model {model_name} loaded and cached.")
    else:
        logger.debug(f"Using cached model: {model_name}")
    
    return model_cache[model_name]

@app.route('/health', methods=['GET', 'POST'])
def health():
    """Health check endpoint with detailed status."""
    return jsonify({
        "status": "ok",
        "models_loaded": list(model_cache.keys()),
        "models_directory": get_models_directory(),
        "timestamp": datetime.now().isoformat()
    }), 200

@app.route('/debug-routes')
def debug_routes():
    routes = []
    for rule in app.url_map.iter_rules():
        routes.append({
            "endpoint": rule.endpoint,
            "methods": list(rule.methods),
            "path": str(rule)
        })
    return jsonify(routes)

@app.route('/preload-model', methods=['POST'])
def preload_model():
    """Preload/download a model."""
    try:
        # Support both form-data and URL-encoded
        model_name = request.form.get('model') or request.values.get('model', 'u2netp')
        logger.info(f"/preload-model requested for: {model_name}")
        
        session = get_session(model_name)
        
        # Confirm presence on disk
        models_dir = get_models_directory()
        model_path = os.path.join(models_dir, f"{model_name}.onnx")
        exists = os.path.exists(model_path)
        
        return jsonify({
            "status": "ok",
            "model": model_name,
            "downloaded": exists,
            "path": model_path
        }), 200
    except Exception as e:
        logger.error(f"Error in /preload-model: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route('/remove-background', methods=['POST'])
def remove_background():
    """Remove background from uploaded image."""
    temp_file = None
    try:
        if 'image' not in request.files:
            logger.warning("Request missing image file")
            return jsonify({"error": "No image provided"}), 400
        
        # Get model name from form data, default to u2netp
        model_name = request.form.get('model', 'u2netp')
        logger.info(f"/remove-background called with model: {model_name}")
        
        # Save uploaded file temporarily
        uploaded_file = request.files['image']
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.png')
        uploaded_file.save(temp_file.name)
        temp_files.append(temp_file.name)
        
        # Process image
        img = Image.open(temp_file.name)
        session = get_session(model_name)
        out = remove(img, session=session)
        
        # Save to buffer
        buf = io.BytesIO()
        out.save(buf, format="PNG")
        buf.seek(0)
        
        # Cleanup
        del img, out
        gc.collect()
        
        logger.info(f"Successfully processed image with model {model_name}")
        return send_file(buf, mimetype="image/png")
        
    except Exception as e:
        logger.error(f"Error in /remove-background: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500
    finally:
        # Cleanup temp file
        if temp_file and os.path.exists(temp_file.name):
            try:
                os.unlink(temp_file.name)
                if temp_file.name in temp_files:
                    temp_files.remove(temp_file.name)
            except Exception as e:
                logger.warning(f"Failed to cleanup temp file: {e}")

############################
# Graceful shutdown support
############################
def cleanup_resources():
    """Cleanup temp files and cached resources."""
    logger.info("Cleaning up resources...")
    
    # Clear model cache
    model_cache.clear()
    gc.collect()
    
    # Remove temp files
    for temp_file in temp_files:
        try:
            if os.path.exists(temp_file):
                os.unlink(temp_file)
                logger.debug(f"Removed temp file: {temp_file}")
        except Exception as e:
            logger.warning(f"Failed to remove temp file {temp_file}: {e}")
    
    temp_files.clear()
    logger.info("Cleanup complete")

def handle_sigterm(*args):
    """Handle termination signal."""
    logger.info("Received shutdown signal")
    cleanup_resources()
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

def find_available_port(start_port=55000, max_attempts=10):
    """Find an available port starting from start_port."""
    for port in range(start_port, start_port + max_attempts):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.bind(('127.0.0.1', port))
            sock.close()
            return port
        except OSError:
            continue
    raise RuntimeError(f"No available ports found in range {start_port}-{start_port + max_attempts}")

def write_port_file(port):
    """Write port number to temp file for Swift to read."""
    try:
        port_file = os.path.join(tempfile.gettempdir(), 'removethatbg_port.json')
        with open(port_file, 'w') as f:
            json.dump({'port': port, 'timestamp': datetime.now().isoformat()}, f)
        logger.info(f"Port file written: {port_file}")
        return port_file
    except Exception as e:
        logger.error(f"Failed to write port file: {e}")
        raise

if __name__ == "__main__":
    logger.info("Starting RemoveThatBG server...")
    
    # Find available port
    port = find_available_port()
    logger.info(f"Using port: {port}")
    
    # Write port to file for Swift to read
    write_port_file(port)
    
    logger.info(f"Server ready on http://127.0.0.1:{port}")
    
    try:
        app.run(host="127.0.0.1", port=port, threaded=True)
    except KeyboardInterrupt:
        logger.info("Server interrupted by user")
    finally:
        cleanup_resources()