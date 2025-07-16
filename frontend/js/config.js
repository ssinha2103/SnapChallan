// Configuration for SnapChallan PWA
const CONFIG = {
  // API Configuration
  API_BASE_URL: 'http://localhost/api',
  WEBSOCKET_URL: 'ws://localhost:8000/ws',
  
  // App Version
  APP_VERSION: '1.0.0',
  
  // Cache Configuration
  CACHE_DURATION: 24 * 60 * 60 * 1000, // 24 hours
  OFFLINE_STORAGE_LIMIT: 50 * 1024 * 1024, // 50MB
  
  // Media Configuration
  MAX_FILE_SIZE: 50 * 1024 * 1024, // 50MB
  MAX_VIDEO_DURATION: 30, // seconds
  MAX_IMAGES_PER_REPORT: 3,
  SUPPORTED_IMAGE_TYPES: ['image/jpeg', 'image/png', 'image/webp'],
  SUPPORTED_VIDEO_TYPES: ['video/mp4', 'video/webm', 'video/mov'],
  
  // Location Configuration
  LOCATION_TIMEOUT: 10000, // 10 seconds
  LOCATION_MAX_AGE: 60000, // 1 minute
  
  // Camera Configuration
  CAMERA_CONSTRAINTS: {
    video: {
      facingMode: 'environment', // Back camera
      width: { ideal: 1920 },
      height: { ideal: 1080 }
    }
  },
  
  // Notification Configuration
  NOTIFICATION_TIMEOUT: 5000, // 5 seconds
  
  // Offline Configuration
  SYNC_RETRY_INTERVAL: 30000, // 30 seconds
  MAX_SYNC_RETRIES: 5,
  
  // Security Configuration
  JWT_STORAGE_KEY: 'snapchallan_tokens',
  USER_STORAGE_KEY: 'snapchallan_user',
  
  // Feature Flags
  FEATURES: {
    PUSH_NOTIFICATIONS: true,
    BACKGROUND_SYNC: true,
    BIOMETRIC_AUTH: false,
    FACE_ID_VERIFICATION: false,
    VOICE_RECORDING: false,
    AR_OVERLAY: false
  },
  
  // Violation Types (will be fetched from API)
  VIOLATION_TYPES: [
    { id: 1, name: 'Wrong Side Driving', code: 'WSD', fine: 1000 },
    { id: 2, name: 'Signal Jump', code: 'SJ', fine: 1000 },
    { id: 3, name: 'No Helmet', code: 'NH', fine: 1000 },
    { id: 4, name: 'Triple Riding', code: 'TR', fine: 1000 },
    { id: 5, name: 'Mobile Phone Usage', code: 'MPU', fine: 1000 },
    { id: 6, name: 'No Seat Belt', code: 'NSB', fine: 1000 },
    { id: 7, name: 'Drunk Driving', code: 'DD', fine: 10000 },
    { id: 8, name: 'Overspeeding', code: 'OS', fine: 2000 },
    { id: 9, name: 'Wrong Parking', code: 'WP', fine: 500 },
    { id: 10, name: 'No Number Plate', code: 'NNP', fine: 5000 }
  ],
  
  // Status Colors
  STATUS_COLORS: {
    pending: '#f59e0b',
    under_review: '#3b82f6',
    approved: '#10b981',
    rejected: '#ef4444',
    challan_issued: '#8b5cf6',
    payment_received: '#059669',
    closed: '#6b7280'
  },
  
  // Toast Types
  TOAST_TYPES: {
    SUCCESS: 'success',
    ERROR: 'error',
    WARNING: 'warning',
    INFO: 'info'
  },
  
  // Network Status
  NETWORK_STATUS: {
    ONLINE: 'online',
    OFFLINE: 'offline',
    SLOW: 'slow'
  },
  
  // Performance Monitoring
  PERFORMANCE: {
    ENABLE_MONITORING: true,
    SAMPLE_RATE: 0.1, // 10% of users
    VITAL_THRESHOLDS: {
      FCP: 1800, // First Contentful Paint
      LCP: 2500, // Largest Contentful Paint
      FID: 100,  // First Input Delay
      CLS: 0.1   // Cumulative Layout Shift
    }
  },
  
  // Error Reporting
  ERROR_REPORTING: {
    ENABLED: true,
    SENTRY_DSN: '', // To be configured
    LOG_LEVEL: 'error'
  },
  
  // Development Mode
  DEV_MODE: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1',
  
  // Analytics
  ANALYTICS: {
    ENABLED: false, // Will be enabled in production
    GA_TRACKING_ID: '',
    FIREBASE_CONFIG: {}
  }
};

// Environment-specific overrides
if (CONFIG.DEV_MODE) {
  CONFIG.API_BASE_URL = 'http://localhost:8000/api';
  CONFIG.WEBSOCKET_URL = 'ws://localhost:8000/ws';
  CONFIG.ERROR_REPORTING.LOG_LEVEL = 'debug';
} else {
  // Production configuration
  CONFIG.API_BASE_URL = 'https://api.snapchallan.com/api';
  CONFIG.WEBSOCKET_URL = 'wss://api.snapchallan.com/ws';
  CONFIG.ANALYTICS.ENABLED = true;
}

// Freeze configuration to prevent modifications
Object.freeze(CONFIG);

// Export for modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}

// Global access
window.CONFIG = CONFIG;
