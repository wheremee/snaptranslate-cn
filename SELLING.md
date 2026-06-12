# 售卖指南（LemonSqueezy 自售卖）

## 一、创建 LemonSqueezy 商店（约 30 分钟）

1. 注册 https://lemonsqueezy.com，创建 Store（需通过审核才能正式收款，先可用测试模式）
2. New Product → 类型选 Digital product / Software license：
   - 上传打包好的 DMG（或填下载链接）
   - 定价建议：一次性买断，$9.9–$19.9 区间（同类工具参考价）
   - **勾选 "Generate license keys"**，Activation limit 建议 2–3（允许用户 2–3 台设备）
3. 复制商品购买页链接

## 二、改两处代码

1. `Sources/SnapTranslate/LicenseManager.swift` 中的 `buyURL` 替换为你的购买页链接
2. 重新打包：`bash Scripts/make_dmg.sh`

## 三、激活流程（已实现）

- 用户首次启动自动开始 7 天全功能试用
- 到期后截图时弹出许可证窗口，含「购买许可证」链接
- 用户购买后收到邮件里的 License Key，粘贴激活（调用 LemonSqueezy 官方激活 API，无需自建服务器）
- 激活状态保存在本机，永久有效

## 四、签名与分发

- 现阶段（无开发者账号）：ad-hoc 签名，用户首次打开需右键 → 打开。请在商品页注明此步骤。
- 注册 Apple Developer（$99/年）后：按 `Scripts/notarize.sh` 顶部注释配置，运行即产出已签名+公证的 DMG，用户双击即装，无任何警告。强烈建议正式售卖前完成这一步。

## 五、上线前检查清单

- [ ] 替换 buyURL
- [ ] 替换占位图标为正式设计（`Scripts/make_icon.swift` 可改）
- [ ] LemonSqueezy 测试模式下买一单，验证 Key 能激活
- [ ] Developer ID 签名 + 公证
- [ ] 商品页写清：系统要求 macOS 13+、需自备翻译 API Key、首次使用需授予屏幕录制权限

## 注意

试用计时与许可证保存在本机文件中，技术熟练者可重置。对工具类软件这是常见取舍（防君子不防小人），v1 不建议为此增加复杂度。税务与合规：LemonSqueezy 作为记录商户（Merchant of Record）代收代缴消费税；个人所得申报请咨询专业人士。
