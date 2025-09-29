"""
org-mode Memory Connector

Конвертирует org-mode файлы в mem-agent формат с использованием pandoc.
"""

from .connector import OrgModeConnector

__all__ = ['OrgModeConnector']