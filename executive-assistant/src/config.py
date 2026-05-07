"""Configuration management for FSP Executive Assistant."""

from functools import lru_cache
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file="config/.env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Core
    anthropic_api_key: str = Field(..., description="Anthropic API key")
    voyage_api_key: str = Field(..., description="Voyage AI API key for embeddings")

    # Slack
    slack_bot_token: str = Field(..., description="Slack bot token (xoxb-...)")
    slack_app_token: str = Field(..., description="Slack app token for Socket Mode")
    slack_signing_secret: str = Field(..., description="Slack signing secret")
    slack_bot_user_id: str = Field(..., description="Bot user ID")

    # Google
    google_client_id: str = Field(..., description="Google OAuth client ID")
    google_client_secret: str = Field(..., description="Google OAuth client secret")
    google_refresh_token: str = Field(..., description="Google OAuth refresh token")
    gmail_additional_accounts: Optional[str] = Field(
        None, description="Comma-separated additional Gmail refresh tokens"
    )

    # QuickBooks
    quickbooks_client_id: str = Field(..., description="QuickBooks client ID")
    quickbooks_client_secret: str = Field(..., description="QuickBooks client secret")
    quickbooks_realm_id: str = Field(..., description="QuickBooks realm/company ID")
    quickbooks_refresh_token: str = Field(..., description="QuickBooks refresh token")

    # Frappe
    frappe_url: Optional[str] = Field(None, description="Frappe instance URL")
    frappe_api_key: Optional[str] = Field(None, description="Frappe API key")
    frappe_api_secret: Optional[str] = Field(None, description="Frappe API secret")

    # Encircle
    encircle_api_key: Optional[str] = Field(None, description="Encircle API key")
    encircle_company_id: Optional[str] = Field(None, description="Encircle company ID")

    # Vector Database
    qdrant_url: str = Field(
        "http://localhost:6333", description="Qdrant server URL"
    )
    qdrant_api_key: Optional[str] = Field(None, description="Qdrant API key")

    # Redis
    redis_url: str = Field(
        "redis://localhost:6379/0", description="Redis connection URL"
    )

    # n8n
    n8n_webhook_url: Optional[str] = Field(None, description="n8n webhook base URL")
    n8n_api_key: Optional[str] = Field(None, description="n8n API key")

    # Server
    api_host: str = Field("0.0.0.0", description="API server host")
    api_port: int = Field(8000, description="API server port")
    log_level: str = Field("INFO", description="Logging level")


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
