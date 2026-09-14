class MobileDetector {
    constructor() {
        this._isMobileCache = null;
        this._deviceTypeCache = null;

        this.isMobile = this.isMobile.bind(this);
        this.getDeviceType = this.getDeviceType.bind(this);

        // Initialize media query matcher
        this.mobileQuery = window.matchMedia('(max-width: 767px), (hover: none)');

        // Reset cache when orientation changes or window resizes
        window.addEventListener('resize', () => this._resetCache());
        window.addEventListener('orientationchange', () => this._resetCache());
    }

    _resetCache() {
        this._isMobileCache = null;
        this._deviceTypeCache = null;
    }

    _hasTouch() {
        return (
            'ontouchstart' in window ||
            navigator.maxTouchPoints > 0 ||
            // @ts-ignore
            navigator.msMaxTouchPoints > 0
        );
    }

    _checkUserAgent() {
        const ua = navigator.userAgent.toLowerCase();
        const mobileKeywords = [
            'mobile',
            'android',
            'iphone',
            'ipad',
            'ipod',
            'blackberry',
            'windows phone',
            'webos',
            'opera mini',
            'opera mobi',
            'samsung',
        ];

        return mobileKeywords.some((keyword) => ua.includes(keyword));
    }

    _checkScreenCharacteristics() {
        const { width, height } = window.screen;
        const smallerDimension = Math.min(width, height);
        const largerDimension = Math.max(width, height);

        // Most mobile devices have one dimension under 1024px
        const isTypicalMobileSize = smallerDimension <= 1024;

        // Check for typical mobile aspect ratios
        const aspectRatio = largerDimension / smallerDimension;
        const isTypicalMobileRatio = aspectRatio >= 1.6 && aspectRatio <= 2.1;

        return isTypicalMobileSize || isTypicalMobileRatio;
    }

    _checkPlatform() {
        const platform = navigator?.platform?.toLowerCase();
        const mobilePlatforms = ['iphone', 'ipod', 'ipad', 'android', 'blackberry', 'webos', 'linux armv'];

        return mobilePlatforms.some((p) => platform.includes(p));
    }

    _checkHoverCapability() {
        // Check if the device supports hover using media query
        const hasHover = window.matchMedia('(hover: hover)').matches;
        const noHover = window.matchMedia('(hover: none)').matches;

        return noHover || !hasHover;
    }

    initialised() {
        return typeof (this._deviceTypeCache !== 'undefined') && this._deviceTypeCache !== null;
    }

    // main API
    isMobile() {
        // Return cached result first if available
        if (this._isMobileCache !== null) {
            return this._isMobileCache;
        }

        // Combine multiple detection methods
        const checks = [
            this._checkUserAgent(),
            this._hasTouch(),
            this._checkScreenCharacteristics(),
            this._checkPlatform(),
            this._checkHoverCapability(),
            this.mobileQuery.matches,
        ];

        // This users device is considered mobile if majority of these checks pass
        const mobileChecksPassed = checks.filter(Boolean).length;
        this._isMobileCache = mobileChecksPassed >= 3;

        return this._isMobileCache;
    }

    /**
     * Get more specific device type info
     * @returns {'mobile'|'tablet'|'desktop'}
     */
    getDeviceType() {
        if (this._deviceTypeCache !== null) {
            return this._deviceTypeCache;
        }

        const ua = navigator.userAgent.toLowerCase();
        const width = window.screen.width;
        const height = window.screen.height;
        const smallerDimension = Math.min(width, height);

        // Tablets
        const isTablet =
            (this._hasTouch() && smallerDimension > 640) ||
            ua.includes('ipad') ||
            (ua.includes('android') && !ua.includes('mobile')) ||
            ua.includes('tablet');

        // Cache and return result
        this._deviceTypeCache = isTablet ? 'tablet' : this.isMobile() ? 'mobile' : 'desktop';
        return this._deviceTypeCache;
    }

    /**
     * Add a listener for device type changes
     * Useful for responsive behavior
     */
    onDeviceTypeChange(callback) {
        const handleChange = () => {
            this._resetCache();
            callback(this.getDeviceType());
        };

        window.addEventListener('resize', handleChange);
        window.addEventListener('orientationchange', handleChange);

        // Return cleanup function
        return () => {
            window.removeEventListener('resize', handleChange);
            window.removeEventListener('orientationchange', handleChange);
        };
    }
}

export const detector = new MobileDetector();
