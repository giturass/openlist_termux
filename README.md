```markdown
# Termux 下的 OpenList

这是一个在 Android Termux 环境中方便安装、更新和管理 [OpenList](https://github.com/openlist/openlist) 的脚本。项目集成了 **aria2** 的安装和管理功能，以提升下载效率。

## 功能
- 在 Termux 中轻松安装和更新 OpenList。
- 集成 aria2 配置，支持高效下载。
- 在 Termux 本地安全存储 GitHub token 和 aria2 RPC secret。

## 前置要求
1. **GitHub 个人访问令牌（Token）**：
   - 用于避免未登录账户频繁调用 GitHub API 导致的限制。
   - **如何获取 GitHub token**：
     1. 访问 [GitHub 设置 > 开发者设置 > 个人访问令牌 > 经典令牌](https://github.com/settings/tokens)。
     2. 点击 **生成新令牌（经典）**。
     3. 选择权限：如需访问私有仓库请选择 `repo`，公开仓库可不选。
     4. 生成并复制令牌。
     - **注意**：首次输入后，token 会安全存储在 Termux 本地，无需重复输入。

2. **aria2 RPC 密钥**：
   - 自行设置一个由字母、数字和符号组成的易记密钥，用于 aria2 的 RPC 认证。
   - 与 GitHub token 相同，密钥会安全存储在 Termux 本地。

## 安装与使用
1. 打开 Termux，在根目录运行以下命令：
   ```bash
   curl -O https://raw.githubusercontent.com/giturass/openlist_termux/refs/heads/main/oplist.sh && chmod +x oplist.sh && ./oplist.sh
   ```
2. 根据交互提示操作：
   - 按提示输入 **GitHub token**（首次输入后本地保存）。
   - 按提示输入 **aria2 RPC 密钥**（同样本地安全保存）。

3. 脚本将自动：
   - 安装或更新 OpenList。
   - 配置并安装 aria2 以支持下载。
   - 安全存储凭据以便后续使用。

## 注意事项
- 安装或更新时请确保网络连接稳定。
- 脚本在 Termux 本地安全存储敏感数据，无需担心安全问题。
- 如有问题或想贡献代码，请访问 [GitHub 仓库](https://github.com/giturass/openlist_termux)。

## 许可证
本项目采用 [MIT 许可证](LICENSE)。
```
