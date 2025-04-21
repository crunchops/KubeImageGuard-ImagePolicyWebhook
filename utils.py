import re
import logging
import json
import base64

logger = logging.getLogger(__name__)

def is_dockerhub_image(image_name):
    """
    Determines if an image is from DockerHub.
    
    DockerHub images are one of:
    - library/name:tag (official images)
    - username/name:tag (user/org images)
    - name:tag (implicit library/ prefix)
    - docker.io/name:tag
    - index.docker.io/name:tag
    
    Non-DockerHub images have other registry domains:
    - k8s.gcr.io/image:tag
    - gcr.io/project/image:tag
    - quay.io/user/image:tag
    - etc.
    """
    
    # Remove the tag or digest portion if present
    if '@' in image_name:  # Image has a digest
        image_name = image_name.split('@')[0]
    elif ':' in image_name:  # Image has a tag
        image_name = image_name.split(':')[0]
    
    # Split the image name into parts
    parts = image_name.split('/')
    
    # Check if the image name has a registry domain
    if len(parts) > 1 and ('.' in parts[0] or ':' in parts[0]):
        registry = parts[0]
        # Verify if it's a DockerHub registry
        return registry in ['docker.io', 'index.docker.io']
    
    # No registry specified, or it's username/repo format
    # Both of these are DockerHub images
    return True

def create_response(uid, allowed, message):
    """
    Creates a properly formatted Kubernetes admission response
    """
    status = {
        "allowed": allowed,
    }
    
    if not allowed:
        status["status"] = {
            "code": 403,
            "message": message
        }
    
    return {
        "apiVersion": "admission.k8s.io/v1",
        "kind": "AdmissionReview",
        "response": {
            "uid": uid,
            "allowed": allowed,
            "status": {
                "message": message
            }
        }
    }

def log_request_response(label, data):
    """
    Logs API requests and responses in a structured format
    """
    try:
        logger.debug(f"{label}: {json.dumps(data, indent=2)}")
    except:
        logger.debug(f"{label}: {data}")
