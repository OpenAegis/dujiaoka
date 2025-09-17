<?php
// 翻译修复脚本
if (!defined('TRANSLATIONS_LOADED')) {
    try {
        if (function_exists('app')) {
            $translator = app('translator');
            $langPath = resource_path('lang/zh_CN/dujiaoka.php');
            
            if (file_exists($langPath)) {
                $translations = include $langPath;
                if (is_array($translations)) {
                    $translator->addLines($translations, 'zh_CN', 'dujiaoka');
                }
            }
        }
    } catch (Exception $e) {
        // 静默处理错误
    }
    define('TRANSLATIONS_LOADED', true);
}