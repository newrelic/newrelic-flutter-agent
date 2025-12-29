/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// Conditional export: use native implementation for mobile platforms,
// and web stub for web/WASM platforms
export 'platform_manager_io.dart'
    if (dart.library.js_interop) 'platform_manager_web.dart';
