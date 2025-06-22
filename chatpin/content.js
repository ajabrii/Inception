/**
 * ChatPin Content Script
 * Adds pin and favorite functionality to ChatGPT interface
 */

class ChatPin {
  constructor() {
    this.pinnedChats = new Set();
    this.favoriteChats = new Set();
    this.observer = null;
    this.filterState = 'all'; // 'all', 'pinned', 'favorites'

    this.init();
  }

  async init() {
    // Load saved data
    await this.loadStoredData();

    // Wait for ChatGPT interface to load
    this.waitForChatGPTInterface();
  }

  async loadStoredData() {
    try {
      const result = await chrome.storage.local.get(['pinnedChats', 'favoriteChats', 'filterState']);
      this.pinnedChats = new Set(result.pinnedChats || []);
      this.favoriteChats = new Set(result.favoriteChats || []);
      this.filterState = result.filterState || 'all';
    } catch (error) {
      console.error('ChatPin: Error loading stored data:', error);
    }
  }

  async saveData() {
    try {
      await chrome.storage.local.set({
        pinnedChats: Array.from(this.pinnedChats),
        favoriteChats: Array.from(this.favoriteChats),
        filterState: this.filterState
      });
    } catch (error) {
      console.error('ChatPin: Error saving data:', error);
    }
  }

  waitForChatGPTInterface() {
    // Wait for the sidebar to appear and stabilize
    const checkForSidebar = () => {
      const sidebar = document.querySelector('nav[aria-label="Chat history"]') ||
                    document.querySelector('nav');

      if (sidebar && document.readyState === 'complete') {
        // Add a small delay to let React finish rendering
        setTimeout(() => {
          this.setupInterface();
        }, 500);
      } else {
        setTimeout(checkForSidebar, 1000);
      }
    };

    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', checkForSidebar);
    } else {
      checkForSidebar();
    }
  }

  setupInterface() {
    this.addFilterControls();
    this.setupChatObserver();
    this.processChatItems();
  }

  addFilterControls() {
    // Find the sidebar container
    const sidebar = document.querySelector('nav[aria-label="Chat history"]') ||
                   document.querySelector('nav');

    if (!sidebar) return;

    // Remove existing filter controls
    const existingFilter = document.getElementById('chatpin-filter');
    if (existingFilter) existingFilter.remove();

    // Create filter controls
    const filterContainer = document.createElement('div');
    filterContainer.id = 'chatpin-filter';
    filterContainer.className = 'chatpin-filter-container';

    filterContainer.innerHTML = `
      <div class="chatpin-filter-buttons">
        <button class="chatpin-filter-btn ${this.filterState === 'all' ? 'active' : ''}" data-filter="all">
          All Chats
        </button>
        <button class="chatpin-filter-btn ${this.filterState === 'pinned' ? 'active' : ''}" data-filter="pinned">
          📌 Pinned
        </button>
        <button class="chatpin-filter-btn ${this.filterState === 'favorites' ? 'active' : ''}" data-filter="favorites">
          ⭐ Favorites
        </button>
      </div>
    `;

    // Add event listeners
    filterContainer.addEventListener('click', (e) => {
      if (e.target.classList.contains('chatpin-filter-btn')) {
        this.handleFilterChange(e.target.dataset.filter);
      }
    });

    // Insert at the top of sidebar
    const firstChild = sidebar.firstElementChild;
    if (firstChild) {
      sidebar.insertBefore(filterContainer, firstChild);
    } else {
      sidebar.appendChild(filterContainer);
    }
  }

  handleFilterChange(newFilter) {
    this.filterState = newFilter;
    this.saveData();

    // Update active button
    document.querySelectorAll('.chatpin-filter-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.filter === newFilter);
    });

    // Apply filter
    this.applyFilter();
  }

  setupChatObserver() {
    // Use a more careful observer that doesn't interfere with React
    const sidebar = document.querySelector('nav[aria-label="Chat history"]') ||
                   document.querySelector('nav');

    if (!sidebar) return;

    // Debounce function to avoid too many updates
    let timeoutId;
    const debouncedProcess = () => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        this.processChatItems();
      }, 300);
    };

    this.observer = new MutationObserver((mutations) => {
      let shouldProcess = false;

      mutations.forEach((mutation) => {
        // Only process if new chat items are added
        if (mutation.addedNodes.length > 0) {
          for (let node of mutation.addedNodes) {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // Check if it's a chat item or contains chat items
              if (node.querySelector && (
                node.matches('a[href*="/c/"]') ||
                node.querySelector('a[href*="/c/"]')
              )) {
                shouldProcess = true;
                break;
              }
            }
          }
        }
      });

      if (shouldProcess) {
        debouncedProcess();
      }
    });

    this.observer.observe(sidebar, {
      childList: true,
      subtree: true
    });
  }

  processChatItems() {
    // Find all chat items - try multiple selectors for different ChatGPT versions
    const chatItems = document.querySelectorAll(
      'nav a[href*="/c/"], ' +
      'nav div[role="button"], ' +
      'nav li a, ' +
      'nav div[class*="group"]:has(a[href*="/c/"]), ' +
      'a[href^="/c/"]'
    );

    chatItems.forEach(item => this.processChatItem(item));
    this.applyFilter();
  }

  processChatItem(chatItem) {
    if (!chatItem || chatItem.hasAttribute('data-chatpin-processed')) return;

    // Mark as processed
    chatItem.setAttribute('data-chatpin-processed', 'true');

    // Get chat ID from href or generate one
    const chatId = this.extractChatId(chatItem);
    if (!chatId) return;

    // Store chat ID on the item for filtering
    chatItem.setAttribute('data-chat-id', chatId);

    // Use a more React-friendly approach - add controls as overlay
    this.addControlsOverlay(chatItem, chatId);
  }

  addControlsOverlay(chatItem, chatId) {
    // Create controls as an overlay that doesn't modify React's DOM structure
    const controlsContainer = document.createElement('div');
    controlsContainer.className = 'chatpin-controls-overlay';
    controlsContainer.setAttribute('data-chat-id', chatId);

    // Create pin button
    const pinBtn = document.createElement('button');
    pinBtn.className = 'chatpin-btn chatpin-pin-btn';
    pinBtn.innerHTML = this.pinnedChats.has(chatId) ? '📌' : '📍';
    pinBtn.title = this.pinnedChats.has(chatId) ? 'Unpin chat' : 'Pin chat';
    pinBtn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.togglePin(chatId, pinBtn);
    });

    // Create favorite button
    const favBtn = document.createElement('button');
    favBtn.className = 'chatpin-btn chatpin-fav-btn';
    favBtn.innerHTML = this.favoriteChats.has(chatId) ? '⭐' : '☆';
    favBtn.title = this.favoriteChats.has(chatId) ? 'Remove from favorites' : 'Add to favorites';
    favBtn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.toggleFavorite(chatId, favBtn);
    });

    controlsContainer.appendChild(pinBtn);
    controlsContainer.appendChild(favBtn);

    // Position the overlay relative to the chat item
    chatItem.style.position = 'relative';
    chatItem.appendChild(controlsContainer);
  }

  // Remove the findInsertionPoint method as we're using overlays now

  extractChatId(chatItem) {
    // Try to get chat ID from href
    const link = chatItem.href || chatItem.querySelector('a')?.href;
    if (link) {
      const match = link.match(/\/c\/([a-zA-Z0-9-]+)/);
      if (match) return match[1];
    }

    // Generate ID from text content as fallback
    const text = chatItem.textContent?.trim();
    if (text) {
      return btoa(text).substring(0, 16);
    }

    return null;
  }

  async togglePin(chatId, button) {
    if (this.pinnedChats.has(chatId)) {
      this.pinnedChats.delete(chatId);
      button.innerHTML = '📍';
      button.title = 'Pin chat';
    } else {
      this.pinnedChats.add(chatId);
      button.innerHTML = '📌';
      button.title = 'Unpin chat';
    }

    await this.saveData();
    this.applyFilter();
  }

  async toggleFavorite(chatId, button) {
    if (this.favoriteChats.has(chatId)) {
      this.favoriteChats.delete(chatId);
      button.innerHTML = '☆';
      button.title = 'Add to favorites';
    } else {
      this.favoriteChats.add(chatId);
      button.innerHTML = '⭐';
      button.title = 'Remove from favorites';
    }

    await this.saveData();
    this.applyFilter();
  }

  applyFilter() {
    const chatItems = document.querySelectorAll('[data-chat-id]');

    chatItems.forEach(item => {
      const chatId = item.getAttribute('data-chat-id');
      const isPinned = this.pinnedChats.has(chatId);
      const isFavorite = this.favoriteChats.has(chatId);

      let shouldShow = true;

      switch (this.filterState) {
        case 'pinned':
          shouldShow = isPinned;
          break;
        case 'favorites':
          shouldShow = isFavorite;
          break;
        case 'all':
        default:
          shouldShow = true;
          break;
      }

      // Show/hide the parent container
      const container = item.closest('li') || item.closest('div[role="listitem"]') || item;
      if (container) {
        container.style.display = shouldShow ? '' : 'none';
      }
    });
  }
}

// Initialize ChatPin with better error handling
(() => {
  // Prevent multiple initializations
  if (window.chatPinInstance) {
    return;
  }

  // Wait for page to be ready
  const initChatPin = () => {
    try {
      window.chatPinInstance = new ChatPin();
    } catch (error) {
      console.error('ChatPin initialization error:', error);
      // Retry after a delay
      setTimeout(initChatPin, 2000);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initChatPin);
  } else {
    // Add delay to avoid conflicts with React
    setTimeout(initChatPin, 1000);
  }
})();

// Handle SPA navigation more carefully
let lastUrl = location.href;
const urlObserver = new MutationObserver(() => {
  const url = location.href;
  if (url !== lastUrl) {
    lastUrl = url;
    // Reset and reinitialize on navigation
    if (window.chatPinInstance && window.chatPinInstance.observer) {
      window.chatPinInstance.observer.disconnect();
    }
    window.chatPinInstance = null;
    setTimeout(() => {
      const initChatPin = () => {
        try {
          window.chatPinInstance = new ChatPin();
        } catch (error) {
          console.error('ChatPin re-initialization error:', error);
        }
      };
      initChatPin();
    }, 1500);
  }
});

urlObserver.observe(document.body, {
  childList: true,
  subtree: true,
  attributes: false,
  characterData: false
});