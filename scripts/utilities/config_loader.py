#!/usr/bin/env python3

"""
Configuration Loader for System Metrics Dashboard (Python)
Provides functions to load and access configuration from config.json
"""

import json
import os
import sys
from pathlib import Path


class ConfigLoader:
    """Configuration loader with environment variable expansion"""

    def __init__(self, config_path=None):
        """
        Initialize config loader
        Args:
            config_path: Path to config.json (auto-detected if None)
        """
        if config_path is None:
            # Auto-detect config path
            script_dir = Path(__file__).parent.resolve()
            self.config_dir = script_dir.parent.parent / "config"
            self.config_path = self.config_dir / "config.json"
        else:
            self.config_path = Path(config_path)
            self.config_dir = self.config_path.parent

        self.config_template = self.config_dir / "config.template.json"
        self.config = None
        self._load()

    def _expand_vars(self, value):
        """Expand environment variables in string values"""
        if isinstance(value, str):
            # Replace ${HOME} with actual home directory
            value = value.replace("${HOME}", os.path.expanduser("~"))
            # Replace ${USER} with actual username
            value = value.replace("${USER}", os.environ.get("USER", ""))
            # Expand ~ for home directory
            if value.startswith("~"):
                value = os.path.expanduser(value)
        elif isinstance(value, dict):
            return {k: self._expand_vars(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [self._expand_vars(item) for item in value]

        return value

    def _load(self):
        """Load configuration from file"""
        if not self.config_path.exists():
            print(f"ERROR: Configuration file not found: {self.config_path}", file=sys.stderr)
            print("Please run the setup script first: ./setup.sh", file=sys.stderr)
            print(f"Or copy {self.config_template} to {self.config_path}", file=sys.stderr)
            sys.exit(1)

        try:
            with open(self.config_path, 'r') as f:
                self.config = json.load(f)

            # Expand environment variables
            self.config = self._expand_vars(self.config)

        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON in config file: {e}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: Failed to load config: {e}", file=sys.stderr)
            sys.exit(1)

    def get(self, key_path, default=None):
        """
        Get config value by dot-notation path
        Args:
            key_path: Dot-separated path (e.g., "paths.logs_dir")
            default: Default value if key not found
        Returns:
            Config value or default
        """
        keys = key_path.split('.')
        value = self.config

        for key in keys:
            if isinstance(value, dict):
                value = value.get(key)
            elif isinstance(value, list) and key.isdigit():
                idx = int(key)
                value = value[idx] if idx < len(value) else None
            else:
                return default

            if value is None:
                return default

        return value

    def get_required(self, key_path):
        """
        Get config value that must exist
        Raises ValueError if not found
        """
        value = self.get(key_path)
        if value is None:
            raise ValueError(f"Required config key not found: {key_path}")
        return value

    def validate(self):
        """
        Validate configuration
        Returns:
            Tuple of (is_valid, errors)
        """
        errors = []

        # Check critical paths
        base_dir = self.get("paths.base_dir")
        if base_dir and not os.path.exists(base_dir):
            errors.append(f"Base directory does not exist: {base_dir}")

        # Check Telegram config if enabled
        if self.get("notifications.telegram.enabled"):
            bot_token = self.get("notifications.telegram.bot_token")
            if not bot_token or bot_token == "YOUR_BOT_TOKEN_HERE":
                errors.append("Telegram bot token not configured")

            chat_id = self.get("notifications.telegram.chat_id")
            if not chat_id or chat_id == "YOUR_CHAT_ID_HERE":
                errors.append("Telegram chat ID not configured")

        return (len(errors) == 0, errors)

    def __getitem__(self, key):
        """Allow dict-like access"""
        return self.get(key)


# Global config instance (lazy-loaded)
_config_instance = None


def get_config(config_path=None):
    """
    Get global config instance
    Args:
        config_path: Optional path to config.json
    Returns:
        ConfigLoader instance
    """
    global _config_instance
    if _config_instance is None:
        _config_instance = ConfigLoader(config_path)
    return _config_instance


# Convenience functions
def get_value(key_path, default=None):
    """Get config value"""
    return get_config().get(key_path, default)


def get_required(key_path):
    """Get required config value"""
    return get_config().get_required(key_path)


# For testing
if __name__ == "__main__":
    config = get_config()
    print("Configuration loaded successfully!")
    print(f"Base directory: {config.get('paths.base_dir')}")
    print(f"Logs directory: {config.get('paths.logs_dir')}")
    print(f"Dashboard port: {config.get('services.dashboard.port')}")
    print(f"Telegram enabled: {config.get('notifications.telegram.enabled')}")

    is_valid, errors = config.validate()
    if is_valid:
        print("\n✓ Configuration is valid")
    else:
        print("\n✗ Configuration has errors:")
        for error in errors:
            print(f"  - {error}")
