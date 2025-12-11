
# Termux 下的 OpenList 管理脚本

这是一个用于在 Android Termux 环境中便捷安装、更新和管理 [OpenList](https://github.com/OpenListTeam/OpenList) 的脚本，简化操作流程并提供丰富功能。

## 功能
- **一键安装与更新**：在 Termux 中快速安装或更新 OpenList。
- **高效下载**：集成 aria2，支持高速下载。
- **快捷命令**：通过 `oplist` 命令快速打开管理菜单。
- **版本检测**：支持非实时检测 OpenList 新版本。
- **开机自启**：支持 OpenList 和 aria2 开机自动启动。
- **数据备份与恢复**：支持本地备份及通过 FTP 上传至云端。
- **外网访问**：通过 Cloudflare Tunnel 实现外网访问。
- **脚本自更新**：保持脚本功能最新。

## 前置要求
1. **安装必要工具**：
   在 Termux 中运行以下命令安装 `curl` 和 `wget`：
   ```bash
   pkg install -y wget curl
   ```

2. **GitHub 个人访问令牌（Token）**：
   - 用途：绕过 GitHub API 速率限制，推荐配置以确保稳定访问。
   - 获取方法：
     1. 访问 [GitHub 设置 > 开发者设置 > 个人访问令牌 > 经典令牌](https://github.com/settings/tokens)。
     2. 点击 **生成新令牌（经典）**。
     3. 权限选择：如需访问私有仓库，勾选 `repo`；公开仓库可无需勾选。
     4. 生成后复制令牌，并保存至 `.env` 文件的 `GITHUB_TOKEN` 字段。
     - **注意**：令牌仅显示一次，务必妥善保存。

3. **aria2 RPC 密钥**：
   - 设置一个由字母、数字和符号组成的密钥，用于 aria2 RPC 认证。
   - 保存至 `.env` 文件的 `ARIA2_SECRET` 字段。

4. **Termux Boot 插件**：
   - 下载地址：[Termux Boot v0.8.1](https://github.com/termux/termux-boot/releases/download/v0.8.1/termux-boot-app_v0.8.1+github.debug.apk)
   - 用途：实现 OpenList 和 aria2 的开机自启。

5. **Cloudflare 账号及托管于其上的域名**：
   - 用于通过 Cloudflare Tunnel 实现 OpenList 的外网访问。
   - 建议提前登录 Cloudflare 账号。

6. **FTP 服务器**：
   - 用于 OpenList 数据云端备份，需提前准备好 FTP 服务器地址和凭据。

## 安装与使用
1. **配置 `.env` 文件**：
   - 从 [https://github.com/giturass/openlist_termux/blob/main/.env](https://github.com/giturass/openlist_termux/blob/main/.env) 获取 `.env` 文件。
   - 编辑并填入 `GITHUB_TOKEN` 和 `ARIA2_SECRET` 等必要字段。
   - 将 `.env` 文件放置于 Termux 主目录（`~`）。

2. **运行安装脚本**：
   在 Termux 中执行以下命令：
   ```bash
   curl -O https://raw.githubusercontent.com/giturass/openlist_termux/main/oplist.sh && chmod +x oplist.sh && ./oplist.sh
   ```


3. **执行流程**：
   - 输入标号 1 安装OpenList。
   - 输入标号 3 启动 openlist 和 aria2。
   - 更多功能 打开 二级菜单功能。

4. **开机自启设置**：
   - 安装 Termux Boot 插件后，脚本会在 OpenList 和 aria2 启动成功后询问是否启用开机自启：
     - 输入 `y` 启用。
     - 输入 `n` 取消。

6. **数据备份与恢复**：
   - **本地备份**：默认保存至 `/sdcard/Download`，可通过脚本修改备份路径。
   - **云端备份**：通过 FTP 上传至云端，需配置以下 `.env` 参数：
     - `FTP_SERVER`：FTP 服务器地址（直接输入 IP 或IP+端口或域名，不加 `ftp://`）。
     - `FTP_PATH`：备份路径，需以 `/` 开始和结束，例如 `/sync/`。

## 快捷使用
安装完成后，可通过以下命令快速打开管理菜单：
```bash
oplist
```
无需记忆复杂路径或参数，即可管理所有功能。

## 注意事项
- **网络稳定性**：安装或更新时请确保网络连接稳定。
- **数据安全**：脚本在 Termux 本地安全存储敏感数据（如 GitHub Token 和 aria2 密钥），无需担心泄露。
- **Cloudflare Tunnel**：确保正确配置 Cloudflare 账号和域名以实现外网访问。
- **FTP 配置**：检查 FTP 服务器地址和凭据的正确性，确保云端备份正常运行。

## 常见问题
- **无法下载文件**：
  - 可能原因：未正确配置 `.env` 文件或网络问题。
  - 解决方案：检查 `.env` 文件，或更换网络环境。
  - 参考 issue：[https://github.com/giturass/openlist_termux/issues/1](https://github.com/giturass/openlist_termux/issues/1)

## 支持与反馈
如有问题或建议，请访问 [项目仓库](https://github.com/giturass/openlist_termux) 提交 issue 或查看文档更新。
```
