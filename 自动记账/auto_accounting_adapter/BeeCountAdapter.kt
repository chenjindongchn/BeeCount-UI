/*
 * Copyright (C) 2025 ankio(ankio@ankio.net)
 * Licensed under the Apache License, Version 3.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-3.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *   limitations under the License.
 */

package net.ankio.auto.adapter

import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import net.ankio.auto.constant.BookFeatures
import net.ankio.auto.storage.Logger
import net.ankio.auto.utils.SystemUtils
import org.ezbook.server.constant.BillAction
import org.ezbook.server.constant.BillType
import org.ezbook.server.db.model.BillInfoModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * BeeCount 记账应用适配器
 *
 * 通过 BeeCount 开放的 URL Scheme 接口将自动识别的账单静默同步到 BeeCount。
 */
class BeeCountAdapter : IAppAdapter {

    override val pkg: String
        get() = "com.tntlikely.beecount"

    override val link: String
        get() = "https://github.com/TNT-Likely/BeeCount"

    override val icon: String
        get() = "https://raw.githubusercontent.com/TNT-Likely/BeeCount/master/assets/images/logo.png"

    override val desc: String
        get() = "BeeCount，简洁纯粹、尊重隐私的现代化开源记账软件。"

    override val name: String
        get() = "BeeCount"

    override fun features(): List<BookFeatures> {
        return listOf(
            BookFeatures.MULTI_BOOK,
            BookFeatures.ASSET_MANAGE,
            BookFeatures.TAG,
            BookFeatures.MULTI_CURRENCY
        )
    }

    override fun supportSyncAssets(): Boolean {
        return false
    }

    override fun syncAssets() {
        // 暂不支持反向资产同步
    }

    override fun syncWaitBills(billAction: BillAction, bookName: String) {
        // 暂不支持待处理账单同步
    }

    override fun syncBill(billInfoModel: BillInfoModel) {
        val url = buildUrl(billInfoModel)

        val intent = Intent(Intent.ACTION_VIEW, url.toUri()).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        // 显式指定包名，优先匹配已安装的开发版或正式版
        val pm = net.ankio.auto.autoApp.packageManager
        val isDevInstalled = try {
            pm.getPackageInfo("com.tntlikely.beecount.dev", 0) != null
        } catch (_: Exception) {
            false
        }
        val isProdInstalled = try {
            pm.getPackageInfo(pkg, 0) != null
        } catch (_: Exception) {
            false
        }

        if (isDevInstalled) {
            intent.setPackage("com.tntlikely.beecount.dev")
        } else if (isProdInstalled) {
            intent.setPackage(pkg)
        }

        Logger.i("BeeCount 目标同步 URI: $url")

        SystemUtils.startActivityIfResolvable(intent, name) {
            AppAdapterManager.markSynced(billInfoModel)
        }
    }

    private fun buildUrl(billInfoModel: BillInfoModel): String {
        val params = mutableMapOf<String, String>()

        // 1. 金额（格式化保留两位小数，避免浮点数精度串扰）
        params["money"] = String.format(Locale.US, "%.2f", billInfoModel.money)

        // 2. 类型：0支出，1收入，2转账
        val type = when (billInfoModel.type) {
            BillType.Income,
            BillType.IncomeLending,
            BillType.IncomeRepayment,
            BillType.IncomeReimbursement,
            BillType.IncomeRefund -> "1"
            BillType.Transfer -> "2"
            else -> "0"
        }
        params["type"] = type

        // 3. 资产账户
        if (billInfoModel.accountNameFrom.isNotEmpty()) {
            params["account_name"] = billInfoModel.accountNameFrom
        }
        if (type == "2" && billInfoModel.accountNameTo.isNotEmpty()) {
            params["target_account"] = billInfoModel.accountNameTo
        }

        // 4. 分类名称
        val (parent, child) = billInfoModel.categoryPair()
        val categoryName = when {
            child.isNotEmpty() -> child
            parent.isNotEmpty() -> parent
            billInfoModel.cateName.isNotEmpty() -> billInfoModel.cateName
            else -> if (type == "1") "收入" else "支出"
        }
        params["cate_name"] = categoryName

        // 5. 商户备注
        val remarkText = when {
            billInfoModel.remark.isNotEmpty() && billInfoModel.shopName.isNotEmpty() ->
                "${billInfoModel.shopName} - ${billInfoModel.remark}"
            billInfoModel.shopName.isNotEmpty() -> billInfoModel.shopName
            billInfoModel.remark.isNotEmpty() -> billInfoModel.remark
            else -> ""
        }
        if (remarkText.isNotEmpty()) {
            params["remark"] = remarkText
        }

        // 6. 时间
        if (billInfoModel.time > 0) {
            val date = Date(billInfoModel.time)
            val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
            params["time"] = sdf.format(date)
        }

        // 7. 账本
        if (billInfoModel.bookName.isNotEmpty() &&
            billInfoModel.bookName != "默认账本" &&
            billInfoModel.bookName != "日常账本"
        ) {
            params["book_name"] = billInfoModel.bookName
        }

        // 8. 默认静默保存
        params["auto_save"] = "1"

        val paramString = params.entries.joinToString("&") { (key, value) ->
            "$key=${Uri.encode(value)}"
        }
        return "beecount://publicapi/addbill?$paramString"
    }

    override fun sleep(): Long {
        return 0L
    }
}
