// ============================================================================
// AutoAccounting 适配器注册补丁示例
// 目标文件：app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt
// ============================================================================

package net.ankio.auto.adapter

/**
 * 在 AppAdapterManager 的 adapters 列表中追加 BeeCountAdapter 即可。
 * 
 * 示例代码位置：
 */
object AppAdapterManager {

    /**
     * 系统已支持的记账应用适配器列表
     */
    val adapters: List<IAppAdapter> = listOf(
        QianJiAdapter(),
        BeeCountAdapter(), // <--- 在此处追加 BeeCount 适配器
        // 其他适配器...
    )

    // ... 其余业务逻辑保持不变
}

/*
Git Diff 参考格式：

diff --git a/app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt b/app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt
--- a/app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt
+++ b/app/src/main/java/net/ankio/auto/adapter/AppAdapterManager.kt
@@ -15,6 +15,7 @@ object AppAdapterManager {
     val adapters: List<IAppAdapter> = listOf(
         QianJiAdapter(),
+        BeeCountAdapter(),
         // ...
     )
*/
