<?php
// 简单的翻译修复函数
if (!function_exists('trans_fix')) {
    function trans_fix($key, $locale = 'zh_CN') {
        static $translations = null;
        
        if ($translations === null) {
            $langFile = __DIR__ . '/resources/lang/' . $locale . '/dujiaoka.php';
            if (file_exists($langFile)) {
                $translations = include $langFile;
            } else {
                $translations = [];
            }
        }
        
        // 解析 dujiaoka.group_all 格式的键
        if (strpos($key, 'dujiaoka.') === 0) {
            $key = substr($key, 9); // 移除 "dujiaoka." 前缀
        }
        
        // 处理嵌套键如 page-title.home
        if (strpos($key, '.') !== false) {
            $keys = explode('.', $key);
            $value = $translations;
            foreach ($keys as $k) {
                if (isset($value[$k])) {
                    $value = $value[$k];
                } else {
                    return 'dujiaoka.' . $key; // 返回原键
                }
            }
            return $value;
        }
        
        return $translations[$key] ?? ('dujiaoka.' . $key);
    }
}