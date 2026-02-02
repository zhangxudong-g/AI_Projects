# 安装说明

## 安装 Node.js 和 npm

如果尚未安装 Node.js，请从 [https://nodejs.org/](https://nodejs.org/) 下载并安装最新 LTS 版本。

## 安装 Promptfoo

运行以下命令安装 promptfoo：

```bash
npm install -g promptfoo
```

或者使用国内镜像：

```bash
npm install -g promptfoo --registry https://registry.npmmirror.com
```

## 验证安装

安装完成后，验证 promptfoo 是否正确安装：

```bash
promptfoo --version
```

## 如果遇到权限问题

在 Windows 上，如果遇到权限问题，可以尝试：

```bash
npm install -g promptfoo --unsafe-perm=true
```

## 替代方案

如果无法安装 promptfoo，您可以使用测试版本来验证系统逻辑：

```bash
cd D:\AI_Projects\promptfoo_wiki\wiki_judges
python pipeline/test_pipeline.py
```

测试版本不会调用真实的 promptfoo，而是生成模拟输出以验证系统架构。