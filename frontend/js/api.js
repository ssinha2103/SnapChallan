// API client for SnapChallan
class APIClient {
  constructor() {
    this.baseURL = CONFIG.API_BASE_URL;
    this.requestQueue = [];
    this.isOnline = navigator.onLine;
    this.setupNetworkListeners();
  }

  setupNetworkListeners() {
    window.addEventListener('online', () => {
      this.isOnline = true;
      this.processOfflineQueue();
      this.hideOfflineBanner();
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
      this.showOfflineBanner();
    });
  }

  showOfflineBanner() {
    const banner = document.getElementById('offline-banner');
    if (banner) {
      banner.classList.remove('hidden');
    }
  }

  hideOfflineBanner() {
    const banner = document.getElementById('offline-banner');
    if (banner) {
      banner.classList.add('hidden');
    }
  }

  // Generic API request method
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const defaultOptions = {
      headers: {
        'Content-Type': 'application/json',
      },
    };

    // Add authorization header if user is authenticated
    if (authManager.isAuthenticated()) {
      const authHeader = authManager.getAuthHeader();
      if (authHeader) {
        defaultOptions.headers['Authorization'] = authHeader;
      }
    }

    const finalOptions = {
      ...defaultOptions,
      ...options,
      headers: {
        ...defaultOptions.headers,
        ...options.headers,
      },
    };

    try {
      const response = await fetch(url, finalOptions);
      
      // Handle token expiration
      if (response.status === 401 && authManager.isAuthenticated()) {
        await authManager.refreshToken();
        // Retry with new token
        const newAuthHeader = authManager.getAuthHeader();
        if (newAuthHeader) {
          finalOptions.headers['Authorization'] = newAuthHeader;
          return await fetch(url, finalOptions);
        }
      }

      return response;
    } catch (error) {
      // Handle offline scenarios
      if (!this.isOnline && options.method !== 'GET') {
        this.queueRequest(endpoint, finalOptions);
        throw new Error('Request queued for when online');
      }
      throw error;
    }
  }

  // Queue requests for offline processing
  queueRequest(endpoint, options) {
    this.requestQueue.push({ endpoint, options, timestamp: Date.now() });
    
    // Store in localStorage for persistence
    try {
      localStorage.setItem('snapchallan_offline_queue', JSON.stringify(this.requestQueue));
    } catch (error) {
      console.error('Failed to store offline queue:', error);
    }
  }

  // Process queued requests when back online
  async processOfflineQueue() {
    if (this.requestQueue.length === 0) {
      // Try to load from localStorage
      try {
        const stored = localStorage.getItem('snapchallan_offline_queue');
        if (stored) {
          this.requestQueue = JSON.parse(stored);
        }
      } catch (error) {
        console.error('Failed to load offline queue:', error);
      }
    }

    while (this.requestQueue.length > 0) {
      const { endpoint, options } = this.requestQueue.shift();
      
      try {
        await this.request(endpoint, options);
        console.log('Offline request processed:', endpoint);
      } catch (error) {
        console.error('Failed to process offline request:', endpoint, error);
        // Re-queue if it fails again
        this.requestQueue.unshift({ endpoint, options, timestamp: Date.now() });
        break;
      }
    }

    // Update localStorage
    try {
      localStorage.setItem('snapchallan_offline_queue', JSON.stringify(this.requestQueue));
    } catch (error) {
      console.error('Failed to update offline queue:', error);
    }
  }

  // GET request
  async get(endpoint, params = {}) {
    const url = new URL(`${this.baseURL}${endpoint}`);
    Object.keys(params).forEach(key => {
      if (params[key] !== undefined && params[key] !== null) {
        url.searchParams.append(key, params[key]);
      }
    });

    const response = await this.request(endpoint + url.search, { method: 'GET' });
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return await response.json();
  }

  // POST request
  async post(endpoint, data = {}) {
    const response = await this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return await response.json();
  }

  // PUT request
  async put(endpoint, data = {}) {
    const response = await this.request(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return await response.json();
  }

  // DELETE request
  async delete(endpoint) {
    const response = await this.request(endpoint, { method: 'DELETE' });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Request failed' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.status === 204 ? {} : await response.json();
  }

  // Upload file with progress
  async uploadFile(endpoint, file, onProgress = null) {
    const formData = new FormData();
    formData.append('file', file);

    const options = {
      method: 'POST',
      body: formData,
      headers: {},
    };

    // Add authorization header
    if (authManager.isAuthenticated()) {
      const authHeader = authManager.getAuthHeader();
      if (authHeader) {
        options.headers['Authorization'] = authHeader;
      }
    }

    // Create XMLHttpRequest for progress tracking
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      // Track upload progress
      if (onProgress) {
        xhr.upload.addEventListener('progress', (e) => {
          if (e.lengthComputable) {
            const progress = (e.loaded / e.total) * 100;
            onProgress(progress);
          }
        });
      }

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            const response = JSON.parse(xhr.responseText);
            resolve(response);
          } catch (error) {
            resolve({});
          }
        } else {
          try {
            const error = JSON.parse(xhr.responseText);
            reject(new Error(error.error || `HTTP ${xhr.status}`));
          } catch (parseError) {
            reject(new Error(`HTTP ${xhr.status}`));
          }
        }
      });

      xhr.addEventListener('error', () => {
        reject(new Error('Upload failed'));
      });

      xhr.open('POST', `${this.baseURL}${endpoint}`);
      
      // Set authorization header
      if (options.headers['Authorization']) {
        xhr.setRequestHeader('Authorization', options.headers['Authorization']);
      }

      xhr.send(formData);
    });
  }

  // Specific API methods for SnapChallan

  // Get violation types
  async getViolationTypes() {
    return await this.get('/violations/types/');
  }

  // Submit violation report
  async submitViolation(violationData) {
    return await this.post('/violations/', violationData);
  }

  // Upload violation media
  async uploadViolationMedia(violationId, file, onProgress) {
    return await this.uploadFile(`/violations/${violationId}/media/`, file, onProgress);
  }

  // Get user's violations
  async getUserViolations(params = {}) {
    return await this.get('/violations/my-reports/', params);
  }

  // Get violation details
  async getViolationDetails(violationId) {
    return await this.get(`/violations/${violationId}/`);
  }

  // Get dashboard statistics
  async getDashboardStats() {
    return await this.get('/violations/dashboard/');
  }

  // Process AI analysis
  async processAIAnalysis(violationId) {
    return await this.post(`/ai/process/${violationId}/`);
  }

  // Get AI results
  async getAIResults(violationId) {
    return await this.get(`/ai/results/${violationId}/`);
  }

  // Payment methods
  async initiateWithdrawal(amount, upiId) {
    return await this.post('/payments/withdraw/', {
      amount: amount,
      upi_id: upiId
    });
  }

  // Get transaction history
  async getTransactions(params = {}) {
    return await this.get('/payments/transactions/', params);
  }

  // Notification methods
  async getNotifications(params = {}) {
    return await this.get('/notifications/', params);
  }

  async markNotificationRead(notificationId) {
    return await this.put(`/notifications/${notificationId}/read/`);
  }

  // Officer portal methods (for admin users)
  async getOfficerDashboard() {
    return await this.get('/officers/dashboard/');
  }

  async getPendingViolations(params = {}) {
    return await this.get('/officers/violations/pending/', params);
  }

  async reviewViolation(violationId, action, notes = '') {
    return await this.post(`/officers/violations/${violationId}/review/`, {
      action: action,
      notes: notes
    });
  }

  async issueChallan(violationId, challanData) {
    return await this.post(`/officers/violations/${violationId}/challan/`, challanData);
  }

  // Health check
  async healthCheck() {
    try {
      const response = await fetch(`${this.baseURL}/health/`);
      return response.ok;
    } catch (error) {
      return false;
    }
  }
}

// Create global instance
const apiClient = new APIClient();

// Export for modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = APIClient;
}

// Global access
window.apiClient = apiClient;
