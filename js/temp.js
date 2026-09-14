/**
 * blah
 */

import { detector as mobileDetector } from './MobileDetector.js';
import { KeyCombo } from './KeyCombo.js';

(() => {
    'use strict';

    document.addEventListener(
        'keydown',
        KeyCombo.on('escape').do(() => {
            console.log(`escape mode ${event}`);
        }),
    );

    document.addEventListener(
        'keydown',
        KeyCombo.on('ctrl+shift+s').do((event) => {
            console.log(`simple mode ${event}`);
        }),
    );
})();
