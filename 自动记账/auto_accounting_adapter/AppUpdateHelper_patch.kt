package net.ankio.auto.update

import android.content.Context
import androidx.core.net.toUri
import net.ankio.auto.BuildConfig
import net.ankio.auto.R
import net.ankio.auto.ui.utils.ToastUtils
import net.ankio.auto.utils.CoroutineUtils.withMain
import net.ankio.auto.utils.PrefManager

/**
 * BeeCount 定制版应用更新工具类说明：
 *
 * 为防止用户在定制版本内误触发官方更新导致安装官方原版覆盖掉 BeeCount 适配器，
 * 将自动检查设为 false，check() 直接返回 null，手动检查提示定制版信息。
 * 规则更新（RuleUpdateHelper）依然保持官方云端更新。
 */
object AppUpdateHelperPatch {
    fun isAutoCheckEnabled(): Boolean = false
    suspend fun check(): Any? = null
    suspend fun checkAndShow(context: Context, fromUser: Boolean) {
        if (fromUser) {
            withMain { ToastUtils.info("当前为 BeeCount 定制版，已是最新版本") }
        }
    }
}
