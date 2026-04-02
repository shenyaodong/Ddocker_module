#!/bin/bash
cd cloudeye-exporter

# 备份原文件
cp logs/logs.go logs/logs.go.bak

# 在 Errorf 函数开头添加 nil 检查
sed -i '/^func (lc \*LoggerConstructor) Errorf(/a \
    if lc == nil || lc.logger == nil {\
        fmt.Printf("[ERROR] "+format+"\\n", v...)\
        return\
    }' logs/logs.go

# 在 Warnf 函数开头添加 nil 检查
sed -i '/^func (lc \*LoggerConstructor) Warnf(/a \
    if lc == nil || lc.logger == nil {\
        fmt.Printf("[WARN] "+format+"\\n", v...)\
        return\
    }' logs/logs.go

# 在 Infof 函数开头添加 nil 检查
sed -i '/^func (lc \*LoggerConstructor) Infof(/a \
    if lc == nil || lc.logger == nil {\
        fmt.Printf("[INFO] "+format+"\\n", v...)\
        return\
    }' logs/logs.go

# 确保导入了 fmt 包
if ! grep -q '"fmt"' logs/logs.go; then
    sed -i '1i package logs\n\nimport "fmt"\n' logs/logs.go
fi

echo "✅ nil pointer fix applied"
