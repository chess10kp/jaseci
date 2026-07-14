import logging;
import from datetime { UTC, datetime }
import from typing { Any }

glob _audit_logger = logging.getLogger('jaclang.scale.identity.audit');

def emit(event: str, **fields: Any) {
    payload: dict[str, Any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}
