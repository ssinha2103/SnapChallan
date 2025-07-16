// Main application controller for SnapChallan PWA
class SnapChallanApp {
  constructor() {
    this.currentView = 'dashboard';
    this.isInitialized = false;
    this.violations = [];
    this.selectedFiles = [];
    this.currentLocation = null;
    
    this.init();
  }

  async init() {
    try {
      await this.initializeApp();
      this.setupEventListeners();
      this.setupNavigation();
      await this.loadInitialData();
      this.hideLoadingScreen();
      this.isInitialized = true;
    } catch (error) {
      console.error('App initialization failed:', error);
      this.showError('Failed to initialize app. Please refresh and try again.');
    }
  }

  async initializeApp() {
    // Check authentication status
    if (!authManager.isAuthenticated()) {
      this.showLoginScreen();
      return;
    }

    // Update user display
    authManager.updateUserDisplay();

    // Setup service worker message listener
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.addEventListener('message', (event) => {
        if (event.data.type === 'SYNC_COMPLETE') {
          this.showToast('Data synchronized', 'success');
          this.refreshCurrentView();
        }
      });
    }

    // Setup push notifications
    await this.setupPushNotifications();

    // Setup periodic sync
    this.setupPeriodicSync();
  }

  setupEventListeners() {
    // Menu toggle
    document.getElementById('menu-btn')?.addEventListener('click', () => {
      this.toggleMenu();
    });

    // Navigation links
    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const href = link.getAttribute('href');
        if (href === '#logout') {
          this.handleLogout();
        } else {
          this.navigateTo(href.substring(1));
        }
      });
    });

    // Violation form
    const violationForm = document.getElementById('violation-form');
    if (violationForm) {
      violationForm.addEventListener('submit', (e) => {
        e.preventDefault();
        this.handleViolationSubmit();
      });
    }

    // File upload
    const uploadArea = document.getElementById('upload-area');
    const mediaFiles = document.getElementById('media-files');
    
    if (uploadArea && mediaFiles) {
      uploadArea.addEventListener('click', () => {
        mediaFiles.click();
      });

      uploadArea.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('dragover');
      });

      uploadArea.addEventListener('dragleave', () => {
        uploadArea.classList.remove('dragover');
      });

      uploadArea.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('dragover');
        this.handleFileUpload(e.dataTransfer.files);
      });

      mediaFiles.addEventListener('change', (e) => {
        this.handleFileUpload(e.target.files);
      });
    }

    // Location button
    document.getElementById('get-location')?.addEventListener('click', () => {
      this.getCurrentLocation();
    });

    // Filter tabs
    document.querySelectorAll('.filter-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        this.filterReports(tab.dataset.status);
      });
    });

    // Profile form
    const profileForm = document.getElementById('profile-form');
    if (profileForm) {
      profileForm.addEventListener('submit', (e) => {
        e.preventDefault();
        this.handleProfileUpdate();
      });
    }

    // KYC button
    document.getElementById('complete-kyc')?.addEventListener('click', () => {
      this.showKYCModal();
    });

    // Withdraw button
    document.getElementById('withdraw-btn')?.addEventListener('click', () => {
      this.showWithdrawModal();
    });

    // Close menu on outside click
    document.addEventListener('click', (e) => {
      const sideNav = document.getElementById('side-nav');
      const menuBtn = document.getElementById('menu-btn');
      
      if (sideNav && !sideNav.contains(e.target) && !menuBtn.contains(e.target)) {
        sideNav.classList.remove('open');
      }
    });

    // Pull to refresh
    this.setupPullToRefresh();

    // Back button handling
    window.addEventListener('popstate', (e) => {
      const view = window.location.hash.substring(1) || 'dashboard';
      this.showView(view);
    });
  }

  setupNavigation() {
    // Set initial view based on URL hash
    const initialView = window.location.hash.substring(1) || 'dashboard';
    this.showView(initialView);
  }

  async loadInitialData() {
    try {
      // Load violation types
      const violationTypes = await apiClient.getViolationTypes();
      this.populateViolationTypes(violationTypes);

      // Load dashboard data
      if (this.currentView === 'dashboard') {
        await this.loadDashboardData();
      }

      // Load user violations
      await this.loadUserViolations();

      // Load wallet data
      await this.loadWalletData();

    } catch (error) {
      console.error('Failed to load initial data:', error);
      if (error.message.includes('401') || error.message.includes('authentication')) {
        authManager.logout();
      }
    }
  }

  populateViolationTypes(types) {
    const select = document.getElementById('violation-type');
    if (!select) return;

    select.innerHTML = '<option value="">Select violation type</option>';
    types.forEach(type => {
      const option = document.createElement('option');
      option.value = type.id;
      option.textContent = `${type.name} (₹${type.fine_amount})`;
      select.appendChild(option);
    });
  }

  async loadDashboardData() {
    try {
      const stats = await apiClient.getDashboardStats();
      this.updateDashboardStats(stats);
    } catch (error) {
      console.error('Failed to load dashboard data:', error);
    }
  }

  updateDashboardStats(stats) {
    document.getElementById('total-reports').textContent = stats.total_reports || 0;
    document.getElementById('approved-reports').textContent = stats.approved_reports || 0;
    document.getElementById('pending-reports').textContent = stats.pending_reports || 0;
    document.getElementById('total-earnings').textContent = `₹${stats.total_earnings || 0}`;
  }

  async loadUserViolations() {
    try {
      const violations = await apiClient.getUserViolations();
      this.violations = violations.results || violations;
      this.renderViolations();
    } catch (error) {
      console.error('Failed to load violations:', error);
    }
  }

  async loadWalletData() {
    try {
      const walletData = await authManager.getWallet();
      this.updateWalletDisplay(walletData);
    } catch (error) {
      console.error('Failed to load wallet data:', error);
    }
  }

  updateWalletDisplay(walletData) {
    const balanceElement = document.getElementById('wallet-balance');
    if (balanceElement) {
      balanceElement.textContent = `₹${walletData.balance || 0}`;
    }

    const transactionsList = document.getElementById('transactions-list');
    if (transactionsList && walletData.transactions) {
      this.renderTransactions(walletData.transactions);
    }
  }

  renderTransactions(transactions) {
    const container = document.getElementById('transactions-list');
    if (!container) return;

    container.innerHTML = '';

    if (transactions.length === 0) {
      container.innerHTML = '<p class="text-center text-secondary">No transactions yet</p>';
      return;
    }

    transactions.forEach(transaction => {
      const item = document.createElement('div');
      item.className = 'transaction-item';
      item.innerHTML = `
        <div class="transaction-info">
          <div class="transaction-description">${transaction.description}</div>
          <div class="transaction-date">${new Date(transaction.created_at).toLocaleDateString()}</div>
        </div>
        <div class="transaction-amount ${transaction.transaction_type}">
          ${transaction.transaction_type === 'credit' ? '+' : '-'}₹${transaction.amount}
        </div>
      `;
      container.appendChild(item);
    });
  }

  toggleMenu() {
    const sideNav = document.getElementById('side-nav');
    if (sideNav) {
      sideNav.classList.toggle('open');
    }
  }

  navigateTo(view) {
    window.location.hash = view;
    this.showView(view);
    this.toggleMenu(); // Close menu after navigation
  }

  showView(viewName) {
    // Hide all views
    document.querySelectorAll('.view').forEach(view => {
      view.classList.remove('active');
    });

    // Show target view
    const targetView = document.getElementById(`${viewName}-view`);
    if (targetView) {
      targetView.classList.add('active');
      this.currentView = viewName;

      // Update navigation
      document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
      });

      const activeLink = document.querySelector(`[href="#${viewName}"]`);
      if (activeLink) {
        activeLink.classList.add('active');
      }

      // Load view-specific data
      this.loadViewData(viewName);
    }
  }

  async loadViewData(viewName) {
    switch (viewName) {
      case 'dashboard':
        await this.loadDashboardData();
        break;
      case 'my-reports':
        await this.loadUserViolations();
        break;
      case 'wallet':
        await this.loadWalletData();
        break;
      case 'profile':
        this.loadProfileData();
        break;
    }
  }

  loadProfileData() {
    const user = authManager.user;
    if (!user) return;

    document.getElementById('profile-name').value = user.first_name || '';
    document.getElementById('profile-email').value = user.email || '';
    document.getElementById('profile-phone').value = user.phone_number || '';
    document.getElementById('profile-city').value = user.city || '';

    // Update KYC status
    const kycStatus = document.getElementById('kyc-status');
    if (kycStatus) {
      const statusBadge = kycStatus.querySelector('.status-badge');
      if (statusBadge) {
        statusBadge.textContent = user.kyc_status || 'pending';
        statusBadge.className = `status-badge ${user.kyc_status || 'pending'}`;
      }
    }

    // Show/hide KYC button
    const kycBtn = document.getElementById('complete-kyc');
    if (kycBtn) {
      kycBtn.style.display = user.kyc_status === 'verified' ? 'none' : 'block';
    }
  }

  async handleViolationSubmit() {
    try {
      this.showLoading('Submitting violation report...');

      const formData = new FormData(document.getElementById('violation-form'));
      const violationData = {
        violation_type: formData.get('violation_type'),
        description: formData.get('description'),
        occurred_at: formData.get('occurred_at'),
        vehicle_number: formData.get('vehicle_number'),
        latitude: this.currentLocation?.latitude,
        longitude: this.currentLocation?.longitude,
        location_address: this.currentLocation?.address || 'Unknown location'
      };

      // Submit violation
      const violation = await apiClient.submitViolation(violationData);

      // Upload files if any
      if (this.selectedFiles.length > 0) {
        for (const file of this.selectedFiles) {
          await apiClient.uploadViolationMedia(violation.id, file, (progress) => {
            this.updateProgress(progress);
          });
        }
      }

      this.hideLoading();
      this.showToast('Violation reported successfully!', 'success');
      
      // Reset form and files
      document.getElementById('violation-form').reset();
      this.selectedFiles = [];
      this.updateMediaPreview();
      
      // Navigate to my reports
      this.navigateTo('my-reports');

    } catch (error) {
      this.hideLoading();
      this.showError(error.message);
    }
  }

  handleFileUpload(files) {
    Array.from(files).forEach(file => {
      if (!this.validateFile(file)) return;
      
      if (this.selectedFiles.length >= CONFIG.MAX_IMAGES_PER_REPORT) {
        this.showError(`Maximum ${CONFIG.MAX_IMAGES_PER_REPORT} files allowed`);
        return;
      }

      this.selectedFiles.push(file);
    });

    this.updateMediaPreview();
  }

  validateFile(file) {
    // Check file size
    if (file.size > CONFIG.MAX_FILE_SIZE) {
      this.showError('File too large. Maximum size is 50MB.');
      return false;
    }

    // Check file type
    const isImage = CONFIG.SUPPORTED_IMAGE_TYPES.includes(file.type);
    const isVideo = CONFIG.SUPPORTED_VIDEO_TYPES.includes(file.type);

    if (!isImage && !isVideo) {
      this.showError('Unsupported file type. Please use JPEG, PNG, or MP4 files.');
      return false;
    }

    return true;
  }

  updateMediaPreview() {
    const preview = document.getElementById('media-preview');
    if (!preview) return;

    preview.innerHTML = '';

    this.selectedFiles.forEach((file, index) => {
      const item = document.createElement('div');
      item.className = 'media-item';

      const isVideo = file.type.startsWith('video/');
      const element = isVideo ? 'video' : 'img';
      
      item.innerHTML = `
        <${element} src="${URL.createObjectURL(file)}" ${isVideo ? 'controls' : ''}>
        <button class="remove-media" onclick="app.removeFile(${index})" type="button">×</button>
      `;

      preview.appendChild(item);
    });
  }

  removeFile(index) {
    this.selectedFiles.splice(index, 1);
    this.updateMediaPreview();
  }

  async getCurrentLocation() {
    try {
      this.showLoading('Getting your location...');

      const position = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: CONFIG.LOCATION_TIMEOUT,
          maximumAge: CONFIG.LOCATION_MAX_AGE
        });
      });

      this.currentLocation = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy
      };

      // Reverse geocode to get address
      await this.reverseGeocode();

      this.hideLoading();
      this.showLocationInfo();

    } catch (error) {
      this.hideLoading();
      this.showError('Could not get your location. Please check location permissions.');
    }
  }

  async reverseGeocode() {
    if (!this.currentLocation) return;

    try {
      // Use a reverse geocoding service (example with OpenStreetMap)
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${this.currentLocation.latitude}&lon=${this.currentLocation.longitude}&zoom=18&addressdetails=1`
      );

      if (response.ok) {
        const data = await response.json();
        this.currentLocation.address = data.display_name;
      }
    } catch (error) {
      console.error('Reverse geocoding failed:', error);
      this.currentLocation.address = `${this.currentLocation.latitude}, ${this.currentLocation.longitude}`;
    }
  }

  showLocationInfo() {
    const locationInfo = document.getElementById('location-info');
    const locationText = document.getElementById('location-text');

    if (locationInfo && locationText && this.currentLocation) {
      locationText.textContent = this.currentLocation.address || 'Location captured';
      locationInfo.classList.remove('hidden');
    }
  }

  renderViolations(filter = 'all') {
    const container = document.getElementById('reports-list');
    if (!container) return;

    container.innerHTML = '';

    let filteredViolations = this.violations;
    if (filter !== 'all') {
      filteredViolations = this.violations.filter(v => v.status === filter);
    }

    if (filteredViolations.length === 0) {
      container.innerHTML = '<p class="text-center text-secondary">No reports found</p>';
      return;
    }

    filteredViolations.forEach(violation => {
      const card = document.createElement('div');
      card.className = 'report-card';
      card.innerHTML = `
        <div class="report-header">
          <div>
            <div class="report-title">${violation.violation_type_name}</div>
            <div class="report-date">${new Date(violation.created_at).toLocaleDateString()}</div>
          </div>
          <span class="status-badge ${violation.status}">${violation.status}</span>
        </div>
        <div class="report-details">
          <p><strong>Vehicle:</strong> ${violation.vehicle_number || 'Not specified'}</p>
          <p><strong>Location:</strong> ${violation.location_address}</p>
          <p><strong>Description:</strong> ${violation.description}</p>
          ${violation.reward_amount > 0 ? `<p><strong>Reward:</strong> ₹${violation.reward_amount}</p>` : ''}
        </div>
      `;
      container.appendChild(card);
    });
  }

  filterReports(status) {
    // Update active tab
    document.querySelectorAll('.filter-tab').forEach(tab => {
      tab.classList.remove('active');
    });
    document.querySelector(`[data-status="${status}"]`).classList.add('active');

    // Filter and render violations
    this.renderViolations(status);
  }

  async handleProfileUpdate() {
    try {
      this.showLoading('Updating profile...');

      const formData = new FormData(document.getElementById('profile-form'));
      const profileData = {
        first_name: formData.get('full_name'),
        email: formData.get('email'),
        city: formData.get('city')
      };

      await authManager.updateProfile(profileData);

      this.hideLoading();
      this.showToast('Profile updated successfully!', 'success');

    } catch (error) {
      this.hideLoading();
      this.showError(error.message);
    }
  }

  async handleLogout() {
    if (confirm('Are you sure you want to logout?')) {
      await authManager.logout();
    }
  }

  showKYCModal() {
    // Implement KYC modal
    this.showToast('KYC verification will be implemented', 'info');
  }

  showWithdrawModal() {
    // Implement withdrawal modal
    this.showToast('UPI withdrawal will be implemented', 'info');
  }

  setupPullToRefresh() {
    let startY = 0;
    let isPulling = false;

    document.addEventListener('touchstart', (e) => {
      if (window.scrollY === 0) {
        startY = e.touches[0].clientY;
        isPulling = true;
      }
    });

    document.addEventListener('touchmove', (e) => {
      if (!isPulling) return;

      const currentY = e.touches[0].clientY;
      const pullDistance = currentY - startY;

      if (pullDistance > 100) {
        this.triggerRefresh();
        isPulling = false;
      }
    });

    document.addEventListener('touchend', () => {
      isPulling = false;
    });
  }

  async triggerRefresh() {
    this.showToast('Refreshing...', 'info');
    await this.refreshCurrentView();
    this.showToast('Refreshed!', 'success');
  }

  async refreshCurrentView() {
    await this.loadViewData(this.currentView);
  }

  async setupPushNotifications() {
    if (!('Notification' in window) || !CONFIG.FEATURES.PUSH_NOTIFICATIONS) {
      return;
    }

    if (Notification.permission === 'default') {
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        console.log('Push notifications permission denied');
        return;
      }
    }

    // Register for push notifications with service worker
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.ready;
      // Implement push subscription
    }
  }

  setupPeriodicSync() {
    // Sync data every 5 minutes when app is active
    setInterval(() => {
      if (document.visibilityState === 'visible' && navigator.onLine) {
        this.syncData();
      }
    }, 5 * 60 * 1000);
  }

  async syncData() {
    try {
      await this.loadInitialData();
    } catch (error) {
      console.error('Background sync failed:', error);
    }
  }

  showLoginScreen() {
    // Redirect to login page or show login modal
    window.location.href = '/login.html';
  }

  hideLoadingScreen() {
    const loadingScreen = document.getElementById('loading-screen');
    const app = document.getElementById('app');

    if (loadingScreen) {
      loadingScreen.style.display = 'none';
    }
    if (app) {
      app.style.display = 'block';
    }
  }

  showLoading(message = 'Loading...') {
    // Implementation for loading state
    console.log('Loading:', message);
  }

  hideLoading() {
    // Implementation for hiding loading state
    console.log('Loading complete');
  }

  updateProgress(progress) {
    console.log('Progress:', progress + '%');
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;

    container.appendChild(toast);

    // Remove toast after timeout
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, CONFIG.NOTIFICATION_TIMEOUT);
  }

  showError(message) {
    this.showToast(message, 'error');
  }
}

// Global functions for HTML onclick handlers
function showDashboardView() {
  app.navigateTo('dashboard');
}

function showReportView() {
  app.navigateTo('report');
}

function showMyReportsView() {
  app.navigateTo('my-reports');
}

function showWalletView() {
  app.navigateTo('wallet');
}

function showProfileView() {
  app.navigateTo('profile');
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.app = new SnapChallanApp();
});

// Export for modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = SnapChallanApp;
}
