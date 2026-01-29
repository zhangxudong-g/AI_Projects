document.addEventListener('DOMContentLoaded', function() {
    const dbPathInput = document.getElementById('dbPath');
    const collectionNameInput = document.getElementById('collectionName');
    const viewBtn = document.getElementById('viewBtn');
    const searchBtn = document.getElementById('searchBtn');
    const searchQueryInput = document.getElementById('searchQuery');
    const limitInput = document.getElementById('limit');
    const browseBtn = document.getElementById('browseBtn');
    const themeSelect = document.getElementById('themeSelect');
    const loadingDiv = document.getElementById('loading');
    const errorDiv = document.getElementById('error');
    const successDiv = document.getElementById('success');
    const collectionsStatsInfo = document.getElementById('collectionsStatsInfo');
    const collectionsStatsContent = document.getElementById('collectionsStatsContent');
    const documentsView = document.getElementById('documentsView');
    const searchResults = document.getElementById('searchResults');

    // 主题切换功能
    function setTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('selectedTheme', theme);
    }

    // 加载保存的主题
    function loadSavedTheme() {
        const savedTheme = localStorage.getItem('selectedTheme') || 'light';
        themeSelect.value = savedTheme;
        setTheme(savedTheme);
    }

    // 初始化主题
    loadSavedTheme();

    // 主题选择变化事件
    themeSelect.addEventListener('change', function() {
        setTheme(this.value);
    });

    // 数据库配置管理相关元素
    const manageDbConfigsBtn = document.getElementById('manageDbConfigsBtn');
    const dbConfigModal = document.getElementById('dbConfigModal');
    const closeDbConfigModal = document.getElementById('closeDbConfigModal');
    const closeDbConfigModalFooter = document.getElementById('closeDbConfigModalFooter');
    const configNameInput = document.getElementById('configName');
    const configPathInput = document.getElementById('configPath');
    const configCollectionInput = document.getElementById('configCollection');
    const saveConfigBtn = document.getElementById('saveConfigBtn');
    const deleteConfigBtn = document.getElementById('deleteConfigBtn');
    const savedConfigsList = document.getElementById('savedConfigsList');
    const dbPathSelect = document.getElementById('dbPathSelect');
    const browseConfigPathBtn = document.getElementById('browseConfigPathBtn');

    // 显示数据库配置管理模态框
    manageDbConfigsBtn.addEventListener('click', function() {
        dbConfigModal.style.display = 'block';
        loadSavedConfigs();

        // 自动填充当前选择的数据库连接信息
        const currentPath = dbPathInput.value;
        const currentCollection = document.getElementById('collectionName').value;

        if (currentPath) {
            configPathInput.value = currentPath;
        }

        if (currentCollection) {
            configCollectionInput.value = currentCollection;
        }
    });

    // 关闭数据库配置管理模态框
    closeDbConfigModal.onclick = function() {
        dbConfigModal.style.display = 'none';
    }

    closeDbConfigModalFooter.onclick = function() {
        dbConfigModal.style.display = 'none';
    }

    window.onclick = function(event) {
        if (event.target === dbConfigModal) {
            dbConfigModal.style.display = 'none';
        }
    }

    // 保存配置
    saveConfigBtn.addEventListener('click', function() {
        const name = configNameInput.value.trim();
        const path = configPathInput.value.trim();
        const collection = configCollectionInput.value.trim();

        if (!name || !path) {
            alert('请填写配置名称和数据库路径');
            return;
        }

        saveDbConfig(name, path, collection);
        loadSavedConfigs(); // 重新加载配置列表
        alert('配置已保存');

        // 清空表单
        configNameInput.value = '';
        configPathInput.value = '';
        configCollectionInput.value = '';
    });

    // 删除配置
    deleteConfigBtn.addEventListener('click', function() {
        const name = configNameInput.value.trim();
        if (!name) {
            alert('请选择要删除的配置');
            return;
        }

        if (confirm(`确定要删除配置 "${name}" 吗？`)) {
            deleteDbConfig(name);
            loadSavedConfigs(); // 重新加载配置列表
            alert('配置已删除');

            // 清空表单
            configNameInput.value = '';
            configPathInput.value = '';
            configCollectionInput.value = '';
        }
    });

    // 浏览配置路径
    browseConfigPathBtn.addEventListener('click', function() {
        // 与浏览按钮相同的逻辑，但应用于配置路径输入框
        alert('请在下方输入框中直接粘贴或输入数据库路径');
        // 实际上，这里应该打开文件夹选择器，但由于浏览器限制，我们只能提示用户手动输入
    });

    // 保存数据库配置到localStorage
    function saveDbConfig(name, path, collection) {
        const configs = JSON.parse(localStorage.getItem('dbConfigs') || '{}');
        configs[name] = {
            path: path,
            collection: collection || 'code_symbols'
        };
        localStorage.setItem('dbConfigs', JSON.stringify(configs));
    }

    // 删除数据库配置
    function deleteDbConfig(name) {
        const configs = JSON.parse(localStorage.getItem('dbConfigs') || '{}');
        delete configs[name];
        localStorage.setItem('dbConfigs', JSON.stringify(configs));
    }

    // 加载已保存的配置
    function loadSavedConfigs() {
        const configs = JSON.parse(localStorage.getItem('dbConfigs') || '{}');
        savedConfigsList.innerHTML = '';

        // 更新下拉选择框
        dbPathSelect.innerHTML = '<option value="">选择已保存的数据库配置</option>';

        let hasConfigs = false;
        for (const name in configs) {
            hasConfigs = true;
            const config = configs[name];

            // 添加到配置列表显示
            const configDiv = document.createElement('div');
            configDiv.className = 'saved-config-item';
            configDiv.innerHTML = `
                <div class="config-item">
                    <strong>${name}</strong>
                    <div>路径: ${config.path}</div>
                    <div>默认集合: ${config.collection}</div>
                    <button class="btn-load" onclick="loadConfig('${name}')">加载</button>
                    <button class="btn-select" onclick="selectConfig('${name}')">选择</button>
                </div>
            `;
            savedConfigsList.appendChild(configDiv);

            // 添加到下拉选择框
            const option = document.createElement('option');
            option.value = name;
            option.textContent = name;
            dbPathSelect.appendChild(option);
        }

        if (!hasConfigs) {
            const noConfigs = document.createElement('p');
            noConfigs.textContent = '暂无已保存的配置';
            noConfigs.style.color = '#777';
            noConfigs.style.fontStyle = 'italic';
            savedConfigsList.appendChild(noConfigs);
        }

        // 显示或隐藏下拉框
        dbPathSelect.style.display = hasConfigs ? 'inline-block' : 'none';
    }

    // 全局函数：加载配置到表单
    window.loadConfig = function(name) {
        const configs = JSON.parse(localStorage.getItem('dbConfigs') || '{}');
        const config = configs[name];
        if (config) {
            configNameInput.value = name;
            configPathInput.value = config.path;
            configCollectionInput.value = config.collection;
        }
    };

    // 全局函数：选择配置并应用到主界面
    window.selectConfig = function(name) {
        const configs = JSON.parse(localStorage.getItem('dbConfigs') || '{}');
        const config = configs[name];
        if (config) {
            dbPathInput.value = config.path;
            // 尝试设置集合名称
            const collectionSelect = document.getElementById('collectionName');
            if (collectionSelect) {
                // 先尝试找到匹配的选项
                let found = false;
                for (let i = 0; i < collectionSelect.options.length; i++) {
                    if (collectionSelect.options[i].value === config.collection) {
                        collectionSelect.selectedIndex = i;
                        found = true;
                        break;
                    }
                }
                // 如果没找到匹配的选项，添加一个新的选项
                if (!found) {
                    const option = document.createElement('option');
                    option.value = config.collection;
                    option.textContent = config.collection;
                    collectionSelect.appendChild(option);
                    collectionSelect.value = config.collection;
                }
            }
            dbConfigModal.style.display = 'none';
            showSuccess(`已选择配置: ${name}`);
        }
    };

    // 监听下拉框选择变化
    dbPathSelect.addEventListener('change', function() {
        if (this.value) {
            selectConfig(this.value);
        }
    });

    // 初始化时加载已保存的配置
    loadSavedConfigs();

    // 侧边栏宽度调整功能
    const resizeHandle = document.getElementById('resizeHandle');
    const controlPanel = document.querySelector('.control-panel');
    const mainLayout = document.querySelector('.main-layout');

    let isResizing = false;

    resizeHandle.addEventListener('mousedown', function(e) {
        isResizing = true;
        document.body.style.userSelect = 'none';
        e.preventDefault();
    });

    document.addEventListener('mousemove', function(e) {
        if (!isResizing) return;

        // 计算新的侧边栏宽度
        const containerRect = mainLayout.getBoundingClientRect();
        const newWidth = e.clientX - containerRect.left;

        // 设置最小和最大宽度限制
        const minWidth = 250;
        const maxWidth = 500;

        if (newWidth >= minWidth && newWidth <= maxWidth) {
            controlPanel.style.width = newWidth + 'px';
        }
    });

    document.addEventListener('mouseup', function() {
        if (isResizing) {
            isResizing = false;
            document.body.style.userSelect = '';

            // 保存当前宽度到localStorage
            const currentWidth = parseInt(controlPanel.style.width) || 320;
            localStorage.setItem('sidebarWidth', currentWidth.toString());
        }
    });

    // 加载保存的侧边栏宽度
    function loadSidebarWidth() {
        const savedWidth = localStorage.getItem('sidebarWidth');
        if (savedWidth) {
            const width = Math.max(250, Math.min(500, parseInt(savedWidth)));
            controlPanel.style.width = width + 'px';
        }
    }

    // 初始化时加载侧边栏宽度
    loadSidebarWidth();

    // 显示加载状态
    function showLoading() {
        loadingDiv.classList.remove('hidden');
        errorDiv.classList.add('hidden');
        successDiv.classList.add('hidden');
    }
    
    // 隐藏加载状态
    function hideLoading() {
        loadingDiv.classList.add('hidden');
    }
    
    // 显示错误信息
    function showError(message) {
        errorDiv.textContent = message;
        errorDiv.classList.remove('hidden');
        successDiv.classList.add('hidden');
    }
    
    // 显示成功信息
    function showSuccess(message) {
        showToast(message, 'success');
    }

    // 显示错误信息
    function showError(message) {
        showToast(message, 'error');
    }

    // 显示Toast通知
    function showToast(message, type = 'success') {
        const toastContainer = document.getElementById('toastContainer');

        // 创建toast元素
        const toast = document.createElement('div');
        toast.className = `toast ${type === 'error' ? 'error-toast' : ''}`;

        // 设置内容
        toast.innerHTML = `
            <span>${message}</span>
            <button class="toast-close">&times;</button>
        `;

        // 添加到容器
        toastContainer.appendChild(toast);

        // 添加关闭事件
        const closeBtn = toast.querySelector('.toast-close');
        closeBtn.addEventListener('click', function() {
            toast.remove();
        });

        // 自动移除toast（5秒后）
        setTimeout(() => {
            if (toast.parentNode) {
                toast.remove();
            }
        }, 5000);
    }
    
    // 隐藏所有结果部分
    function hideAllResults() {
        collectionsStatsInfo.classList.add('hidden');
        documentsView.classList.add('hidden');
        searchResults.classList.add('hidden');
    }
    
    // 查看数据功能
    viewBtn.addEventListener('click', async function() {
        const dbPath = dbPathInput.value.trim();
        const collectionName = collectionNameInput.value.trim() || 'code_symbols';
        const limit = parseInt(limitInput.value) || 10;
        
        if (!dbPath) {
            showError('请先输入数据库路径');
            return;
        }
        
        showLoading();
        hideAllResults();
        
        try {
            const response = await fetch('/api/view', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    db_path: dbPath,
                    collection_name: collectionName,
                    limit: limit
                })
            });
            
            const result = await response.json();
            
            hideLoading();
            
            if (result.error) {
                showError(result.error);
                return;
            }
            
            // 显示集合信息
            if (result.collections || result.stats) {
                let content = '';

                if (result.collections && result.collections.length > 0) {
                    content += '<div class="collections-section"><h4>可用集合</h4><ul>';

                    result.collections.forEach(col => {
                        content += `<li>${col.name} (元数据: ${JSON.stringify(col.metadata)})</li>`;
                    });

                    content += '</ul></div>';
                }

                if (result.stats) {
                    content += `<div class="stats-section"><h4>统计信息</h4><p>集合 '${result.stats.collection_name}' 包含 ${result.stats.count} 个文档</p></div>`;
                }

                collectionsStatsContent.innerHTML = content;
                collectionsStatsInfo.classList.remove('hidden');
            }
            
            // 显示文档内容
            if (result.documents && result.documents.length > 0) {
                const documentsList = document.getElementById('documentsList');
                documentsList.innerHTML = '';
                
                result.documents.forEach((doc, index) => {
                    const div = document.createElement('div');
                    div.className = 'document-item';
                    
                    div.innerHTML = `
                        <h4>文档 ${index + 1}: ID=${doc.id}</h4>
                        <p><strong>内容预览:</strong></p>
                        <p>${doc.content}</p>
                        <div class="content-toggle">展开/收起</div>
                        <div class="metadata">
                            <p><strong>元数据:</strong></p>
                            ${Object.entries(doc.metadata).map(([key, value]) =>
                                `<p><strong>${key}:</strong> ${value}</p>`
                            ).join('')}
                            <div class="metadata-toggle">展开/收起元数据</div>
                        </div>
                    `;

                    // 添加展开/收起内容功能
                    const contentToggle = div.querySelector('.content-toggle');
                    if (contentToggle) {
                        contentToggle.addEventListener('click', function() {
                            div.classList.toggle('full-content');
                            contentToggle.textContent = div.classList.contains('full-content') ? '收起内容' : '展开内容';
                        });
                    }

                    // 添加展开/收起元数据功能
                    const metadataToggle = div.querySelector('.metadata-toggle');
                    const metadataDiv = div.querySelector('.metadata');
                    if (metadataToggle && metadataDiv) {
                        metadataToggle.addEventListener('click', function() {
                            const isHidden = metadataDiv.style.display === 'none';
                            metadataDiv.style.display = isHidden ? 'block' : 'none';
                            metadataToggle.textContent = isHidden ? '收起元数据' : '展开元数据';
                        });
                    }

                    // 默认隐藏元数据
                    metadataDiv.style.display = 'none';
                    
                    documentsList.appendChild(div);
                });
                
                documentsView.classList.remove('hidden');
                showSuccess(`成功加载 ${result.documents.length} 个文档`);
            } else {
                showSuccess('集合为空或没有找到文档');
            }
        } catch (error) {
            hideLoading();
            showError(`请求失败: ${error.message}`);
        }
    });
    
    // 移除旧的浏览功能，使用新的模态框方式

    // 辅助函数：验证路径是否有效
    function isValidPath(path) {
        // 简单验证路径格式
        return typeof path === 'string' && path.trim().length > 0;
    }

    // 文件夹选择模态框相关元素
    const modal = document.getElementById('folderModal');
    const closeModal = document.getElementById('closeModal');
    const cancelFolderSelection = document.getElementById('cancelFolderSelection');
    const goHome = document.getElementById('goHome');
    const goUp = document.getElementById('goUp');
    const currentPath = document.getElementById('currentPath');
    const folderContents = document.getElementById('folderContents');

    // 当前浏览路径
    let currentBrowsePath = '';

    // 显示文件夹选择模态框
    browseBtn.addEventListener('click', function() {
        // 初始化模态框
        showModal();
        loadDirectoryContent('.');
    });

    // 关闭模态框
    closeModal.onclick = function() {
        modal.style.display = 'none';
    }

    cancelFolderSelection.onclick = function() {
        modal.style.display = 'none';
    }

    window.onclick = function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    }

    // 导航按钮事件
    goHome.onclick = function() {
        loadDirectoryContent('~');  // 使用波浪号表示用户主目录
    }

    goUp.onclick = function() {
        if (currentBrowsePath && currentBrowsePath !== '/') {
            const parentPath = currentBrowsePath.substring(0, currentBrowsePath.lastIndexOf('/')) || '/';
            loadDirectoryContent(parentPath);
        }
    }

    // 显示模态框
    function showModal() {
        modal.style.display = 'block';
    }

    // 加载目录内容
    async function loadDirectoryContent(path) {
        try {
            // 如果路径是波浪号，替换为实际的用户主目录
            if (path === '~') {
                path = '';  // 让后端决定默认路径
            }

            const response = await fetch('/api/list_directory', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ path: path })
            });

            const result = await response.json();

            if (result.error) {
                showError(result.error);
                return;
            }

            // 更新当前路径显示
            currentBrowsePath = result.current_path;
            currentPath.textContent = currentBrowsePath;

            // 清空当前内容
            folderContents.innerHTML = '';

            // 添加返回上级目录选项（如果不是根目录）
            if (result.parent_path) {
                const upItem = document.createElement('div');
                upItem.className = 'folder-item';
                upItem.innerHTML = '<i>📁</i><div>.. (上级目录)</div>';
                upItem.onclick = () => loadDirectoryContent(result.parent_path);
                folderContents.appendChild(upItem);
            }

            // 添加所有子目录
            result.directories.forEach(dir => {
                const dirItem = document.createElement('div');
                dirItem.className = 'folder-item';
                dirItem.innerHTML = '<i>📁</i><div>' + dir.name + '</div>';
                dirItem.onclick = () => {
                    if (dir.is_chroma_db) {
                        // 如果是ChromaDB目录，直接选择
                        dbPathInput.value = dir.path;
                        modal.style.display = 'none';
                        // 加载该数据库的集合
                        loadCollectionsForPath(dir.path);
                        showSuccess(`已选择数据库路径: ${dir.path}`);
                    } else {
                        // 否则进入该目录
                        loadDirectoryContent(dir.path);
                    }
                };
                folderContents.appendChild(dirItem);
            });

            // 添加所有ChromaDB文件（如果有）
            if (result.chroma_dbs && result.chroma_dbs.length > 0) {
                result.chroma_dbs.forEach(db => {
                    const dbItem = document.createElement('div');
                    dbItem.className = 'folder-item';
                    dbItem.innerHTML = '<i>🗄️</i><div>' + db.name + ' (DB)</div>';
                    dbItem.onclick = () => {
                        dbPathInput.value = db.path;
                        modal.style.display = 'none';
                        // 加载该数据库的集合
                        loadCollectionsForPath(db.path);
                        showSuccess(`已选择数据库路径: ${db.path}`);
                    };
                    folderContents.appendChild(dbItem);
                });
            }

        } catch (error) {
            showError(`加载目录内容失败: ${error.message}`);
        }
    }

    // 加载指定路径的集合
    async function loadCollectionsForPath(dbPath) {
        try {
            const response = await fetch('/api/get_collections', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ db_path: dbPath })
            });

            const result = await response.json();

            if (result.collections) {
                // 清空现有的集合选项
                const collectionSelect = document.getElementById('collectionName');
                collectionSelect.innerHTML = '';

                // 添加新的集合选项
                result.collections.forEach(collection => {
                    const option = document.createElement('option');
                    option.value = collection.name;
                    option.textContent = `${collection.name} (${collection.count} 个项目)`;
                    collectionSelect.appendChild(option);
                });

                // 如果有集合，选择第一个
                if (result.collections.length > 0) {
                    collectionSelect.selectedIndex = 0;
                }
            }
        } catch (error) {
            console.error('加载集合失败:', error);
        }
    }

    // 保存最近的选择到localStorage
    function saveRecentSelections(dbPath, collectionName) {
        const recent = JSON.parse(localStorage.getItem('recentSelections') || '[]');

        // 添加新的选择
        const newSelection = {
            dbPath: dbPath,
            collectionName: collectionName,
            timestamp: Date.now()
        };

        // 检查是否已存在相同的记录，如果存在则移除
        const filtered = recent.filter(item =>
            !(item.dbPath === dbPath && item.collectionName === collectionName)
        );

        // 添加新记录到开头
        filtered.unshift(newSelection);

        // 只保留最近的5条记录
        const limited = filtered.slice(0, 5);

        localStorage.setItem('recentSelections', JSON.stringify(limited));
    }

    // 加载最近的选择
    function loadRecentSelections() {
        const recent = JSON.parse(localStorage.getItem('recentSelections') || '[]');
        return recent;
    }

    // 更新数据库路径输入框，并加载最近的选择
    dbPathInput.addEventListener('focus', function() {
        const recent = loadRecentSelections();
        if (recent.length > 0) {
            // 创建提示元素（如果不存在）
            let hintElement = document.getElementById('pathHint');
            if (!hintElement) {
                hintElement = document.createElement('div');
                hintElement.id = 'pathHint';
                hintElement.className = 'path-hint';
                hintElement.style.cssText = `
                    position: absolute;
                    background: white;
                    border: 1px solid #ddd;
                    border-top: none;
                    width: 100%;
                    max-height: 150px;
                    overflow-y: auto;
                    z-index: 100;
                    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
                `;
                const container = dbPathInput.parentNode;
                container.style.position = 'relative';
                container.appendChild(hintElement);
            }

            // 填充最近的路径
            hintElement.innerHTML = '';
            recent.forEach((item, index) => {
                const div = document.createElement('div');
                div.className = 'hint-item';
                div.style.cssText = `
                    padding: 8px 12px;
                    cursor: pointer;
                    border-bottom: 1px solid #eee;
                `;
                div.textContent = `${item.dbPath} (集合: ${item.collectionName})`;
                div.onclick = function() {
                    dbPathInput.value = item.dbPath;
                    const collectionSelect = document.getElementById('collectionName');
                    const options = collectionSelect.options;
                    for (let i = 0; i < options.length; i++) {
                        if (options[i].value === item.collectionName) {
                            collectionSelect.selectedIndex = i;
                            break;
                        }
                    }
                    hintElement.style.display = 'none';
                };
                hintElement.appendChild(div);
            });

            hintElement.style.display = 'block';
        }
    });

    // 点击其他地方隐藏提示
    document.addEventListener('click', function(event) {
        if (event.target !== dbPathInput) {
            const hintElement = document.getElementById('pathHint');
            if (hintElement) {
                hintElement.style.display = 'none';
            }
        }
    });

    // 保存选择
    viewBtn.addEventListener('click', function() {
        const dbPath = dbPathInput.value.trim();
        const collectionName = document.getElementById('collectionName').value;
        if (dbPath && collectionName) {
            saveRecentSelections(dbPath, collectionName);
        }
    });

    searchBtn.addEventListener('click', function() {
        const dbPath = dbPathInput.value.trim();
        const collectionName = document.getElementById('collectionName').value;
        if (dbPath && collectionName) {
            saveRecentSelections(dbPath, collectionName);
        }
    });

    // 搜索数据功能
    searchBtn.addEventListener('click', async function() {
        const dbPath = dbPathInput.value.trim();
        const collectionName = collectionNameInput.value.trim() || 'code_symbols';
        const queryText = searchQueryInput.value.trim();
        const nResults = parseInt(limitInput.value) || 5;

        if (!dbPath) {
            showError('请先输入数据库路径');
            return;
        }

        if (!queryText) {
            showError('请输入搜索查询');
            return;
        }

        showLoading();
        hideAllResults();

        try {
            const response = await fetch('/api/search', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    db_path: dbPath,
                    query_text: queryText,
                    collection_name: collectionName,
                    n_results: nResults
                })
            });

            const result = await response.json();

            hideLoading();

            if (result.error) {
                showError(result.error);
                return;
            }

            if (result.info) {
                showSuccess(result.info);
                return;
            }

            // 显示搜索结果
            if (result.results && result.results.length > 0) {
                const searchResultsList = document.getElementById('searchResultsList');
                searchResultsList.innerHTML = '';

                result.results.forEach((res, index) => {
                    const div = document.createElement('div');
                    div.className = 'search-result';

                    div.innerHTML = `
                        <h4>结果 ${index + 1}: ID=${res.id}</h4>
                        <p><strong>相似度:</strong> <span class="similarity-score">${res.similarity}</span></p>
                        <p><strong>内容预览:</strong></p>
                        <p>${res.content}</p>
                        <div class="content-toggle">展开/收起</div>
                        <div class="metadata">
                            <p><strong>元数据:</strong></p>
                            ${Object.entries(res.metadata).map(([key, value]) =>
                                `<p><strong>${key}:</strong> ${value}</p>`
                            ).join('')}
                            <div class="metadata-toggle">展开/收起元数据</div>
                        </div>
                    `;

                    // 添加展开/收起内容功能
                    const contentToggle = div.querySelector('.content-toggle');
                    if (contentToggle) {
                        contentToggle.addEventListener('click', function() {
                            div.classList.toggle('full-content');
                            contentToggle.textContent = div.classList.contains('full-content') ? '收起内容' : '展开内容';
                        });
                    }

                    // 添加展开/收起元数据功能
                    const metadataToggle = div.querySelector('.metadata-toggle');
                    const metadataDiv = div.querySelector('.metadata');
                    if (metadataToggle && metadataDiv) {
                        metadataToggle.addEventListener('click', function() {
                            const isHidden = metadataDiv.style.display === 'none';
                            metadataDiv.style.display = isHidden ? 'block' : 'none';
                            metadataToggle.textContent = isHidden ? '收起元数据' : '展开元数据';
                        });
                    }

                    // 默认隐藏元数据
                    metadataDiv.style.display = 'none';

                    searchResultsList.appendChild(div);
                });

                searchResults.classList.remove('hidden');
                showSuccess(`找到 ${result.results.length} 个匹配项，搜索查询: "${result.query}"`);
            } else {
                showSuccess('没有找到匹配的结果');
            }
        } catch (error) {
            hideLoading();
            showError(`搜索请求失败: ${error.message}`);
        }
    });
});