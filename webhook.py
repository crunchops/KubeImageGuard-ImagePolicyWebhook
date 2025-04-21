import json
import logging
import base64
from flask import Blueprint, request, jsonify
from utils import is_dockerhub_image, create_response, log_request_response

# Set up logging
logger = logging.getLogger(__name__)

# Create Blueprint
webhook_bp = Blueprint('webhook', __name__)

# Store in-memory admission review statistics
stats = {
    'total_requests': 0,
    'allowed_requests': 0,
    'denied_requests': 0,
}

@webhook_bp.route('/webhook', methods=['POST'])
def validate_images():
    """
    Main webhook endpoint to validate images based on admission requests
    """
    from app import log_handler
    
    # Increment total requests counter
    stats['total_requests'] += 1
    
    # Parse the admission review request
    try:
        admission_review = request.json
        logger.debug(f"Received admission review: {json.dumps(admission_review)}")
        log_request_response("REQUEST", admission_review)
        log_handler.add_log({"type": "request", "data": admission_review})
        
        # Extract relevant information
        request_obj = admission_review.get('request', {})
        uid = request_obj.get('uid', '')
        namespace = request_obj.get('namespace', '')
        name = request_obj.get('name', '')
        kind = request_obj.get('kind', {}).get('kind', '')
        operation = request_obj.get('operation', '')
        
        logger.info(f"Processing {operation} for {kind}/{name} in namespace {namespace}")
        
        # Extract container images from the request
        object_spec = request_obj.get('object', {}).get('spec', {})
        containers = []
        
        # Handle different resource types
        if kind.lower() == 'pod':
            containers = object_spec.get('containers', [])
            init_containers = object_spec.get('initContainers', [])
            ephemeral_containers = object_spec.get('ephemeralContainers', [])
            containers.extend(init_containers)
            containers.extend(ephemeral_containers)
        elif kind.lower() in ['deployment', 'statefulset', 'daemonset', 'replicaset', 'job']:
            containers = object_spec.get('template', {}).get('spec', {}).get('containers', [])
            init_containers = object_spec.get('template', {}).get('spec', {}).get('initContainers', [])
            ephemeral_containers = object_spec.get('template', {}).get('spec', {}).get('ephemeralContainers', [])
            containers.extend(init_containers)
            containers.extend(ephemeral_containers)
        elif kind.lower() == 'cronjob':
            containers = object_spec.get('jobTemplate', {}).get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            init_containers = object_spec.get('jobTemplate', {}).get('spec', {}).get('template', {}).get('spec', {}).get('initContainers', [])
            ephemeral_containers = object_spec.get('jobTemplate', {}).get('spec', {}).get('template', {}).get('spec', {}).get('ephemeralContainers', [])
            containers.extend(init_containers)
            containers.extend(ephemeral_containers)
        
        # If no containers found, allow the request
        if not containers:
            logger.warning(f"No containers found in {kind}/{name} in namespace {namespace}")
            response = create_response(uid, True, "No containers found to validate")
            log_request_response("RESPONSE (ALLOWED - No containers)", response)
            log_handler.add_log({"type": "response", "data": response, "allowed": True})
            stats['allowed_requests'] += 1
            return jsonify(response)
        
        # Validate images
        non_dockerhub_images = []
        for container in containers:
            image = container.get('image', '')
            if image and not is_dockerhub_image(image):
                non_dockerhub_images.append(f"{container.get('name', 'unknown')}: {image}")
        
        # Make decision based on validation results
        if non_dockerhub_images:
            message = f"Non-DockerHub images are not allowed: {', '.join(non_dockerhub_images)}"
            logger.warning(message)
            response = create_response(uid, False, message)
            log_request_response("RESPONSE (DENIED)", response)
            log_handler.add_log({"type": "response", "data": response, "allowed": False})
            stats['denied_requests'] += 1
            return jsonify(response)
        else:
            message = "All container images are from DockerHub"
            logger.info(message)
            response = create_response(uid, True, message)
            log_request_response("RESPONSE (ALLOWED)", response)
            log_handler.add_log({"type": "response", "data": response, "allowed": True})
            stats['allowed_requests'] += 1
            return jsonify(response)
            
    except Exception as e:
        logger.error(f"Error processing webhook request: {str(e)}", exc_info=True)
        # In case of error, allow the request to avoid blocking cluster operations
        response = create_response(uid if 'uid' in locals() else '', True, f"Error: {str(e)}")
        log_request_response("RESPONSE (ERROR - ALLOWED)", response)
        log_handler.add_log({"type": "error", "data": str(e)})
        stats['allowed_requests'] += 1
        return jsonify(response)

@webhook_bp.route('/stats', methods=['GET'])
def get_stats():
    """Return admission webhook statistics"""
    return jsonify(stats)
