// Authentication module for SnapChallan
class AuthManager {
  constructor() {
    this.tokens = this.getStoredTokens();
    this.user = this.getStoredUser();
    this.refreshTimer = null;
    this.init();
  }

  init() {
    // Set up token refresh timer
    if (this.tokens?.access) {
      this.setupTokenRefresh();
    }

    // Listen for storage changes (multi-tab sync)
    window.addEventListener('storage', (e) => {
      if (e.key === CONFIG.JWT_STORAGE_KEY) {
        this.tokens = this.getStoredTokens();
        if (!this.tokens) {
          this.logout();
        }
      }
    });
  }

  // Get stored tokens from localStorage
  getStoredTokens() {
    try {
      const stored = localStorage.getItem(CONFIG.JWT_STORAGE_KEY);
      return stored ? JSON.parse(stored) : null;
    } catch (error) {
      console.error('Error parsing stored tokens:', error);
      return null;
    }
  }

  // Get stored user from localStorage
  getStoredUser() {
    try {
      const stored = localStorage.getItem(CONFIG.USER_STORAGE_KEY);
      return stored ? JSON.parse(stored) : null;
    } catch (error) {
      console.error('Error parsing stored user:', error);
      return null;
    }
  }

  // Store tokens securely
  storeTokens(tokens) {
    try {
      localStorage.setItem(CONFIG.JWT_STORAGE_KEY, JSON.stringify(tokens));
      this.tokens = tokens;
      this.setupTokenRefresh();
    } catch (error) {
      console.error('Error storing tokens:', error);
      throw new Error('Failed to store authentication tokens');
    }
  }

  // Store user data
  storeUser(user) {
    try {
      localStorage.setItem(CONFIG.USER_STORAGE_KEY, JSON.stringify(user));
      this.user = user;
      this.updateUserDisplay();
    } catch (error) {
      console.error('Error storing user data:', error);
    }
  }

  // Update user display in UI
  updateUserDisplay() {
    if (!this.user) return;

    const userNameElement = document.getElementById('user-name');
    const userStatusElement = document.getElementById('user-status');

    if (userNameElement) {
      userNameElement.textContent = this.user.first_name || this.user.username || 'User';
    }

    if (userStatusElement) {
      const statusText = this.user.kyc_status === 'verified' ? 'Verified' : 'Pending Verification';
      userStatusElement.textContent = statusText;
      userStatusElement.className = `status ${this.user.kyc_status}`;
    }
  }

  // Check if user is authenticated
  isAuthenticated() {
    return !!(this.tokens?.access && !this.isTokenExpired(this.tokens.access));
  }

  // Check if token is expired
  isTokenExpired(token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return Date.now() >= payload.exp * 1000;
    } catch (error) {
      return true;
    }
  }

  // Get authorization header
  getAuthHeader() {
    if (!this.tokens?.access) {
      return null;
    }
    return `Bearer ${this.tokens.access}`;
  }

  // Setup automatic token refresh
  setupTokenRefresh() {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }

    if (!this.tokens?.access) return;

    try {
      const payload = JSON.parse(atob(this.tokens.access.split('.')[1]));
      const expiryTime = payload.exp * 1000;
      const currentTime = Date.now();
      const timeUntilExpiry = expiryTime - currentTime;

      // Refresh 5 minutes before expiry
      const refreshTime = Math.max(timeUntilExpiry - 5 * 60 * 1000, 1000);

      this.refreshTimer = setTimeout(() => {
        this.refreshToken();
      }, refreshTime);
    } catch (error) {
      console.error('Error setting up token refresh:', error);
    }
  }

  // Refresh access token
  async refreshToken() {
    if (!this.tokens?.refresh) {
      this.logout();
      return;
    }

    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/token/refresh/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          refresh: this.tokens.refresh
        })
      });

      if (response.ok) {
        const data = await response.json();
        this.storeTokens({
          access: data.access,
          refresh: this.tokens.refresh
        });
      } else {
        // Refresh token is invalid, logout user
        this.logout();
      }
    } catch (error) {
      console.error('Token refresh failed:', error);
      this.logout();
    }
  }

  // Send OTP
  async sendOTP(phoneNumber, purpose) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/otp/request/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phone_number: phoneNumber,
          purpose: purpose
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to send OTP');
      }

      return data;
    } catch (error) {
      console.error('OTP send error:', error);
      throw error;
    }
  }

  // Register user
  async register(userData) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/register/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(userData)
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Registration failed');
      }

      // Store tokens and user data
      this.storeTokens(data.tokens);
      this.storeUser(data.user);

      return data;
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  }

  // Login user
  async login(phoneNumber, password) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/login/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phone_number: phoneNumber,
          password: password
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Login failed');
      }

      // Store tokens and user data
      this.storeTokens(data.tokens);
      this.storeUser(data.user);

      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  // Logout user
  async logout() {
    try {
      // Clear refresh timer
      if (this.refreshTimer) {
        clearTimeout(this.refreshTimer);
        this.refreshTimer = null;
      }

      // Attempt to blacklist token on server
      if (this.tokens?.refresh) {
        await fetch(`${CONFIG.API_BASE_URL}/auth/logout/`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': this.getAuthHeader()
          },
          body: JSON.stringify({
            refresh_token: this.tokens.refresh
          })
        });
      }
    } catch (error) {
      console.error('Logout API error:', error);
    } finally {
      // Always clear local storage
      localStorage.removeItem(CONFIG.JWT_STORAGE_KEY);
      localStorage.removeItem(CONFIG.USER_STORAGE_KEY);
      this.tokens = null;
      this.user = null;

      // Redirect to login or refresh page
      if (window.location.hash !== '#login') {
        window.location.hash = '#login';
        window.location.reload();
      }
    }
  }

  // Complete KYC verification
  async completeKYC(aadhaarNumber, otpCode) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/kyc/verify/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.getAuthHeader()
        },
        body: JSON.stringify({
          aadhaar_number: aadhaarNumber,
          otp_code: otpCode
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'KYC verification failed');
      }

      // Update stored user data
      this.storeUser(data.user);

      return data;
    } catch (error) {
      console.error('KYC verification error:', error);
      throw error;
    }
  }

  // Update user profile
  async updateProfile(profileData) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/profile/`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': this.getAuthHeader()
        },
        body: JSON.stringify(profileData)
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Profile update failed');
      }

      // Update stored user data
      this.storeUser(data);

      return data;
    } catch (error) {
      console.error('Profile update error:', error);
      throw error;
    }
  }

  // Reset password
  async resetPassword(phoneNumber, otpCode, newPassword) {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/password/reset/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phone_number: phoneNumber,
          otp_code: otpCode,
          new_password: newPassword,
          confirm_password: newPassword
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Password reset failed');
      }

      return data;
    } catch (error) {
      console.error('Password reset error:', error);
      throw error;
    }
  }

  // Get user wallet information
  async getWallet() {
    try {
      const response = await fetch(`${CONFIG.API_BASE_URL}/auth/wallet/`, {
        method: 'GET',
        headers: {
          'Authorization': this.getAuthHeader()
        }
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to fetch wallet data');
      }

      return data;
    } catch (error) {
      console.error('Wallet fetch error:', error);
      throw error;
    }
  }

  // Check authentication status
  checkAuthStatus() {
    if (!this.isAuthenticated()) {
      this.logout();
      return false;
    }
    return true;
  }
}

// Create global instance
const authManager = new AuthManager();

// Export for modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = AuthManager;
}

// Global access
window.authManager = authManager;
