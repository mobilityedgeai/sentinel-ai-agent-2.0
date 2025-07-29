package com.mycompany.sentinelinsights

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.util.*
import kotlin.concurrent.timer

/**
 * Foreground Service especializado em manter o Sentinel AI funcionando continuamente
 * Implementa múltiplas estratégias para evitar ser morto pelo sistema
 */
class AntiKillForegroundService : Service() {
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var keepAliveTimer: Timer? = null
    private var heartbeatTimer: Timer? = null
    private var notificationManager: NotificationManager? = null
    
    companion object {
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "sentinel_ai_anti_kill"
        private const val WAKELOCK_TAG = "SentinelAI:AntiKillService"
        
        // Intervalos de monitoramento
        private const val KEEP_ALIVE_INTERVAL = 5 * 60 * 1000L // 5 minutos
        private const val HEARTBEAT_INTERVAL = 30 * 1000L // 30 segundos
        
        // Estatísticas do serviço
        var serviceStartTime = 0L
        var keepAliveCount = 0L
        var heartbeatCount = 0L
        var isServiceRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        
        serviceStartTime = System.currentTimeMillis()
        isServiceRunning = true
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Criar canal de notificação
        createNotificationChannel()
        
        // Configurar wake lock
        setupWakeLock()
        
        // Iniciar monitoramento contínuo
        startKeepAliveMonitoring()
        startHeartbeatMonitoring()
        
        println("🛡️ AntiKillForegroundService iniciado")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Obter notificação personalizada se fornecida
        val notification = intent?.getParcelableExtra<Notification>("notification") 
            ?: createDefaultNotification()
        
        // Iniciar como foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, 
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // Retornar START_STICKY para reiniciar automaticamente se morto
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        
        isServiceRunning = false
        
        // Limpar recursos
        releaseWakeLock()
        stopKeepAliveMonitoring()
        stopHeartbeatMonitoring()
        
        println("🛡️ AntiKillForegroundService destruído")
        
        // Tentar reiniciar o serviço
        restartService()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        
        println("⚠️ Task removida - tentando manter serviço ativo")
        
        // Não parar o serviço quando a task é removida
        // Isso ajuda a manter o app funcionando mesmo quando removido da bandeja de recentes
    }

    /**
     * Cria canal de notificação para Android 8.0+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Sentinel AI - Sistema Anti-Kill",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantém o Sentinel AI funcionando continuamente em background"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            
            notificationManager?.createNotificationChannel(channel)
        }
    }

    /**
     * Cria notificação padrão do serviço
     */
    private fun createDefaultNotification(): Notification {
        val uptime = System.currentTimeMillis() - serviceStartTime
        val uptimeText = formatUptime(uptime)
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sentinel AI - Proteção Ativa")
            .setContentText("Sistema anti-kill ativo • Uptime: $uptimeText")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setLocalOnly(true)
            .build()
    }

    /**
     * Configura wake lock para manter CPU ativa
     */
    private fun setupWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            // Usar tag específica baseada no fabricante
            val tag = when {
                Build.MANUFACTURER.equals("Huawei", ignoreCase = true) && 
                Build.VERSION.SDK_INT == Build.VERSION_CODES.M -> {
                    "LocationManagerService" // Tag whitelisted para EMUI 4
                }
                else -> WAKELOCK_TAG
            }
            
            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag)
            wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 horas máximo
            
            println("🔋 Wake lock adquirido com tag: $tag")
        } catch (e: Exception) {
            println("❌ Erro ao configurar wake lock: ${e.message}")
        }
    }

    /**
     * Inicia monitoramento keep-alive
     */
    private fun startKeepAliveMonitoring() {
        keepAliveTimer = timer("KeepAlive", false, 0L, KEEP_ALIVE_INTERVAL) {
            performKeepAliveCheck()
        }
    }

    /**
     * Inicia monitoramento de heartbeat
     */
    private fun startHeartbeatMonitoring() {
        heartbeatTimer = timer("Heartbeat", false, 0L, HEARTBEAT_INTERVAL) {
            sendHeartbeat()
        }
    }

    /**
     * Executa verificação keep-alive
     */
    private fun performKeepAliveCheck() {
        try {
            keepAliveCount++
            
            // Verificar se wake lock ainda está ativo
            if (wakeLock?.isHeld != true) {
                println("⚠️ Wake lock perdido - reativando...")
                setupWakeLock()
            }
            
            // Atualizar notificação com estatísticas
            updateNotification()
            
            // Verificar memória disponível
            checkMemoryStatus()
            
            // Verificar se o processo principal ainda está ativo
            checkMainProcessStatus()
            
            println("✅ Keep-alive check #$keepAliveCount completado")
            
        } catch (e: Exception) {
            println("❌ Erro no keep-alive check: ${e.message}")
        }
    }

    /**
     * Envia heartbeat para monitoramento
     */
    private fun sendHeartbeat() {
        try {
            heartbeatCount++
            
            // Registrar heartbeat no sistema
            val timestamp = System.currentTimeMillis()
            
            // Aqui poderia enviar heartbeat via FCM ou salvar localmente
            // Por simplicidade, apenas logamos
            
            if (heartbeatCount % 10 == 0L) { // Log a cada 10 heartbeats (5 minutos)
                println("💓 Heartbeat #$heartbeatCount - Serviço ativo há ${formatUptime(timestamp - serviceStartTime)}")
            }
            
        } catch (e: Exception) {
            println("❌ Erro no heartbeat: ${e.message}")
        }
    }

    /**
     * Atualiza notificação com estatísticas atuais
     */
    private fun updateNotification() {
        try {
            val uptime = System.currentTimeMillis() - serviceStartTime
            val uptimeText = formatUptime(uptime)
            
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Sentinel AI - Proteção Ativa")
                .setContentText("Anti-kill ativo • Uptime: $uptimeText • Checks: $keepAliveCount")
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setAutoCancel(false)
                .setShowWhen(false)
                .setLocalOnly(true)
                .build()
            
            notificationManager?.notify(NOTIFICATION_ID, notification)
            
        } catch (e: Exception) {
            println("❌ Erro ao atualizar notificação: ${e.message}")
        }
    }

    /**
     * Verifica status da memória
     */
    private fun checkMemoryStatus() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            val availableMemoryMB = memoryInfo.availMem / (1024 * 1024)
            val totalMemoryMB = memoryInfo.totalMem / (1024 * 1024)
            val memoryPercentage = (availableMemoryMB.toDouble() / totalMemoryMB.toDouble()) * 100
            
            if (memoryPercentage < 10) {
                println("⚠️ Memória baixa: ${availableMemoryMB}MB disponível (${memoryPercentage.toInt()}%)")
            }
            
        } catch (e: Exception) {
            println("❌ Erro ao verificar memória: ${e.message}")
        }
    }

    /**
     * Verifica status do processo principal
     */
    private fun checkMainProcessStatus() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningProcesses = activityManager.runningAppProcesses
            
            val mainProcess = runningProcesses?.find { 
                it.processName == packageName 
            }
            
            if (mainProcess == null) {
                println("⚠️ Processo principal não encontrado - possível morte do app")
            } else {
                val importance = when (mainProcess.importance) {
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "FOREGROUND"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_BACKGROUND -> "BACKGROUND"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "SERVICE"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> "CACHED"
                    else -> "UNKNOWN"
                }
                
                if (keepAliveCount % 12 == 0L) { // Log a cada 12 checks (1 hora)
                    println("📊 Processo principal: $importance (PID: ${mainProcess.pid})")
                }
            }
            
        } catch (e: Exception) {
            println("❌ Erro ao verificar processo principal: ${e.message}")
        }
    }

    /**
     * Para monitoramento keep-alive
     */
    private fun stopKeepAliveMonitoring() {
        keepAliveTimer?.cancel()
        keepAliveTimer = null
    }

    /**
     * Para monitoramento de heartbeat
     */
    private fun stopHeartbeatMonitoring() {
        heartbeatTimer?.cancel()
        heartbeatTimer = null
    }

    /**
     * Libera wake lock
     */
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    println("🔋 Wake lock liberado")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            println("❌ Erro ao liberar wake lock: ${e.message}")
        }
    }

    /**
     * Tenta reiniciar o serviço
     */
    private fun restartService() {
        try {
            // Agendar reinicialização após pequeno delay
            val restartIntent = Intent(this, AntiKillForegroundService::class.java)
            val pendingIntent = PendingIntent.getService(
                this, 
                0, 
                restartIntent, 
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val restartTime = System.currentTimeMillis() + 5000 // 5 segundos
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    restartTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    restartTime,
                    pendingIntent
                )
            }
            
            println("🔄 Reinicialização do serviço agendada")
            
        } catch (e: Exception) {
            println("❌ Erro ao agendar reinicialização: ${e.message}")
        }
    }

    /**
     * Formata tempo de uptime
     */
    private fun formatUptime(uptimeMs: Long): String {
        val seconds = uptimeMs / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        val days = hours / 24
        
        return when {
            days > 0 -> "${days}d ${hours % 24}h"
            hours > 0 -> "${hours}h ${minutes % 60}m"
            minutes > 0 -> "${minutes}m ${seconds % 60}s"
            else -> "${seconds}s"
        }
    }
}

