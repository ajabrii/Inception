/**
 * ChatPin Background Script
 * Manages extension state and handles cross-tab synchronization
 */

class ChatPinBackground {
  constructor() {
    this.init();
  }

  init() {
    // Listen for installation/update events
    chrome.runtime.onInstalled.addListener((details) => {
      this.handleInstall(details);
    });

    // Listen for storage changes to sync across tabs
    chrome.storage.onChanged.addListener((changes, namespace) => {
      this.handleStorageChange(changes, namespace);
    });

    // Listen for messages from content scripts
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
      this.handleMessage(message, sender, sendResponse);
    });

    // Handle extension icon click
    chrome.action.onClicked.addListener((tab) => {
      this.handleActionClick(tab);
    });
  }

  async handleInstall(details) {
    if (details.reason === 'install') {
      // First time installation
      console.log('ChatPin extension installed');

      // Initialize default settings
      await chrome.storage.local.set({
        pinnedChats: [],
        favoriteChats: [],
        filterState: 'all',
        settings: {
          showNotifications: true,
          syncAcrossTabs: true
        }
      });

      // Open welcome page or instructions
      chrome.tabs.create({
        url: 'https://chat.openai.com'
      });
    } else if (details.reason === 'update') {
      console.log('ChatPin extension updated');
      // Handle any migration logic here if needed
    }
  }

  handleStorageChange(changes, namespace) {
    if (namespace === 'local') {
      // Notify all ChatGPT tabs about storage changes
      this.notifyTabs(changes);
    }
  }

  async notifyTabs(changes) {
    try {
      const tabs = await chrome.tabs.query({
        url: ['https://chat.openai.com/*', 'https://chatgpt.com/*']
      });

      tabs.forEach(tab => {
        chrome.tabs.sendMessage(tab.id, {
          type: 'STORAGE_CHANGED',
          changes: changes
        }).catch(() => {
          // Ignore errors for tabs that don't have content script loaded
        });
      });
    } catch (error) {
      console.error('ChatPin: Error notifying tabs:', error);
    }
  }

  handleMessage(message, sender, sendResponse) {
    switch (message.type) {
      case 'GET_STATS':
        this.getStats().then(sendResponse);
        return true; // Indicates async response

      case 'EXPORT_DATA':
        this.exportData().then(sendResponse);
        return true;

      case 'IMPORT_DATA':
        this.importData(message.data).then(sendResponse);
        return true;

      case 'RESET_DATA':
        this.resetData().then(sendResponse);
        return true;

      default:
        console.log('ChatPin: Unknown message type:', message.type);
    }
  }

  async handleActionClick(tab) {
    // Check if we're on a ChatGPT page
    if (tab.url.includes('chat.openai.com') || tab.url.includes('chatgpt.com')) {
      // Toggle the filter or show stats
      try {
        await chrome.tabs.sendMessage(tab.id, {
          type: 'TOGGLE_FILTER'
        });
      } catch (error) {
        console.log('ChatPin: Content script not ready');
      }
    } else {
      // Open ChatGPT
      chrome.tabs.create({
        url: 'https://chat.openai.com'
      });
    }
  }

  async getStats() {
    try {
      const data = await chrome.storage.local.get(['pinnedChats', 'favoriteChats']);
      return {
        pinnedCount: (data.pinnedChats || []).length,
        favoriteCount: (data.favoriteChats || []).length,
        totalManaged: new Set([
          ...(data.pinnedChats || []),
          ...(data.favoriteChats || [])
        ]).size
      };
    } catch (error) {
      console.error('ChatPin: Error getting stats:', error);
      return { pinnedCount: 0, favoriteCount: 0, totalManaged: 0 };
    }
  }

  async exportData() {
    try {
      const data = await chrome.storage.local.get(['pinnedChats', 'favoriteChats', 'settings']);
      return {
        success: true,
        data: {
          pinnedChats: data.pinnedChats || [],
          favoriteChats: data.favoriteChats || [],
          settings: data.settings || {},
          exportDate: new Date().toISOString(),
          version: chrome.runtime.getManifest().version
        }
      };
    } catch (error) {
      console.error('ChatPin: Error exporting data:', error);
      return { success: false, error: error.message };
    }
  }

  async importData(importData) {
    try {
      if (!importData || !importData.pinnedChats && !importData.favoriteChats) {
        throw new Error('Invalid import data format');
      }

      await chrome.storage.local.set({
        pinnedChats: importData.pinnedChats || [],
        favoriteChats: importData.favoriteChats || [],
        settings: { ...(await this.getCurrentSettings()), ...(importData.settings || {}) }
      });

      return { success: true };
    } catch (error) {
      console.error('ChatPin: Error importing data:', error);
      return { success: false, error: error.message };
    }
  }

  async resetData() {
    try {
      await chrome.storage.local.set({
        pinnedChats: [],
        favoriteChats: [],
        filterState: 'all'
      });

      return { success: true };
    } catch (error) {
      console.error('ChatPin: Error resetting data:', error);
      return { success: false, error: error.message };
    }
  }

  async getCurrentSettings() {
    try {
      const result = await chrome.storage.local.get(['settings']);
      return result.settings || {
        showNotifications: true,
        syncAcrossTabs: true
      };
    } catch (error) {
      console.error('ChatPin: Error getting current settings:', error);
      return {};
    }
  }
}

// Initialize the background script
new ChatPinBackground();