@php
// Blade模板翻译辅助函数
if (!function_exists('dujiaoka_trans')) {
    function dujiaoka_trans($key) {
        static $cache = null;
        
        if ($cache === null) {
            $langFile = resource_path('lang/zh_CN/dujiaoka.php');
            $cache = file_exists($langFile) ? include $langFile : [];
        }
        
        // 移除 dujiaoka. 前缀
        if (strpos($key, 'dujiaoka.') === 0) {
            $key = substr($key, 9);
        }
        
        // 处理嵌套键
        if (strpos($key, '.') !== false) {
            $keys = explode('.', $key);
            $value = $cache;
            foreach ($keys as $k) {
                $value = $value[$k] ?? null;
                if ($value === null) return $key;
            }
            return $value;
        }
        
        return $cache[$key] ?? $key;
    }
}
@endphp