# Cupertino uosc 本地改造

原配置备份：`backups/pre-cupertino.tar.gz`。重启 mpv 后生效。

- Cupertino 图标来自 Flutter 官方字体，映射在 `scripts/uosc/lib/cupertino.lua`；菜单、音量、空闲页等共用这套字体。
- 单轨章节间隔：展开 3px / 收起 1px；展开轨道 3px、收起 2px。普通章节灰白，片头/片尾蓝色，广告红色；已播放最亮、缓存中等、未缓存最暗。沿用 uosc 章节和 SponsorBlock 区间数据，不新增广告检测服务。
- 进度条无圆球指针；18px Noto Sans 计时/倒计时位于轨道左右两侧并垂直居中。
- 时间、章节悬浮提示、thumbfast、拖动定位、滚轮定位和 A/B 标记保留。
- 顶部高度 36px，红黄绿按钮直径 14px、中心间距 23px、首个按钮中心距左边 17px；顶部无背景，24px Noto Sans 标题居中，关闭/最小化/最大化在左侧。圆形按钮按 MacTahoe SVG 的双层几何与颜色绘制；原 SVG 留在 `scripts/uosc/assets/mactahoe/`。窗口外部圆角由桌面合成器控制。
- 键盘 RIGHT 短按快进 5 秒；鼠标右键短按保留菜单/控件原操作。长按 350ms 临时切到 2x（当前速度更快则不减速），松开、失焦、鼠标离开窗口或切换文件恢复原速度。参数在 `script-opts/hold-speed.conf`。
- `border=no` 使用自绘标题栏；视频区域仍可拖动窗口。

字体来源：https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons
映射来源：https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/cupertino/icons.dart
授权见 `LICENSES/`。

这些修改直接作用于本地 uosc；使用上游 uosc 更新功能会覆盖源码定制，请先保留本目录。

顶栏使用 uosc 原生距离渐变：距顶栏区域 40px 内完全显示，40–120px 渐隐，120px 外隐藏。窗口和全屏均生效；取消加载文件时自动闪现。

章节悬停时轨道从 3px 增粗到 5px；悬停轨道时以 Cupertino play_rectangle_fill 标记实际播放位置，标记字号 12px（小型矩形），180ms 三次缓出动画从中心向外放大出现，移开时以 160ms 三次缓出动画向中心收拢并淡出；快速移入移出从当前大小平滑反向。时间文字距窗口边缘 12px，轨道按整段媒体时间格式和播放速度预留数字宽度，文字与轨道间另留 14px。

快进/后退动画位于 `scripts/seek_feedback.lua`：键盘连续同向跳转累计秒数，左右箭头依次闪动，随后淡出；原生 OSD 状态文本与进度条关闭。
