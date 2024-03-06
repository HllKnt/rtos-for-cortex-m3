    .thumb
    .syntax unified

# strex是保证互斥的关键 必须消耗ldrex产生的标志信息才能赋值
# 标志信息保存在相应的监视器中 每个核心有各自的本地监视器 多核心额外共享全局监视器
# ldrex的标志信息不叠加 监视器只保留最新的
# 可以总结 有两种情况导致strex失败
# 1: 在执行strex之前切换进程 该锁被其他进程上锁
# 2: 在执行strex之前切换进程 其他进程对另一把锁赋值消耗ldrex标志信息
# 因此strex失败后判断是哪种情况
# 多核且配有缓存 strex应该落实到内存 使用关键字volatile修饰表示锁的变量
    .section .text

    .type _spin_lock, function
    .global _spin_lock
# c代码中函数声明为 void _spin_lock(Lock *lock);
# r0 需要上锁的变量的地址
# 数值0 表示未上锁
# 数值1 表示已上锁
# 参考《cortex-m3权威指南》13.3.1 
_spin_lock:
# 给变量赋值为1 上锁阶段使用 
    mov r1, #1
_spin_lock_check_angain:
    ldrex r2, [r0]
# 判断是否上锁
    cmp r2, #0
# 变量已经上锁则重复判断 从而实现自旋等待
    bne _spin_lock_check_angain
# 未上锁 尝试赋值上锁
    strex r2, r1, [r0]
# 判断是否成功赋值
    cmp r2, #0
# 检查是哪种原因导致赋值失败 如果已经上锁则进入自旋等待
    bne _spin_lock_check_angain
    bx lr
    
    .type _spin_unlock, function
    .global _spin_unlock
# c代码中函数声明为 void _spin_unlock(Lock *lock);
_spin_unlock:
    mov r1, #0
    str r1, [r0]
    bx lr

    .type _mutex_lock, function
    .global _mutex_lock
# c代码中函数声明为 char _mutex_lock(Lock *lock);
# 返回0 表示 上锁操作失败 
# 返回1 表示 上锁操作成功
# r0 需要上锁的变量的地址
# 数值0 表示未上锁
# 数值1 表示已上锁
# 参考《cortex-m3权威指南》10.7
_mutex_lock:
# 给变量赋值为1 上锁阶段使用 
    mov r1, #1
_mutex_lock_check_again:
    ldrex r2, [r0]
# 判断是否已经上锁
    cmp r2, #0
# 已经上锁 直接返回上锁操作失败
    bne _mutex_lock_failed
    strex r2, r1, [r0]
# 判断是否成功赋值
    cmp r2, #0
# 赋值失败 如果已经上锁则返回上锁失败 否则重新赋值
    bne _mutex_lock_check_again
_mutex_lock_successed:
    mov r0, #1
    bx lr
_mutex_lock_failed:
    mov r0, #0
    bx lr

    .type _mutex_unlock, function
    .global _mutex_unlock
# c代码中函数声明为 void _mutex_unlock(Lock *lock);
_mutex_unlock:
    mov r1, #0
    str r1, [r0]
    bx lr

    .end
