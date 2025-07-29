package com.mycompany.sentinelinsights

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*
import kotlin.collections.HashMap

/**
 * Plugin nativo para implementar funcionalidades anti-kill específicas por fabricante
 */
class AntiKillPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var powerManager: PowerManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var notificationManager: NotificationManager? = null
    
    // Estatísticas do serviço
    private val stats = HashMap<String, Any>()
    private var heartbeatCount = 0L
    private var lastHeartbeat = 0L
    private var serviceStartTime = 0L

    companion object {
        private const val CHANNEL = "com.mycompany.sentinelinsights/anti_kill"
        private const val NOTIFICATION_CHANNEL_ID = "sentinel_ai_anti_kill"
        private const val FOREGROUND_SERVICE_ID = 2001
        
        // Tags whitelisted para Huawei EMUI 4
        private val HUAWEI_WHITELISTED_TAGS = arrayOf(
            "AudioMix", "AudioIn", "AudioDup", 
            "AudioDirectOut", "AudioOffload", "LocationManagerService"
        )
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        serviceStartTime = System.currentTimeMillis()
        initializeStats()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseWakeLock()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "setHuaweiWakelockTag" -> setHuaweiWakelockTag(call, result)
                "requestProtectedAppsWhitelist" -> requestProtectedAppsWhitelist(result)
                "requestStartupManagerPermission" -> requestStartupManagerPermission(result)
                "detectPowerGenie" -> detectPowerGenie(result)
                "requestMIUIAppPinning" -> requestMIUIAppPinning(result)
                "checkMIUIAutostartStatus" -> checkMIUIAutostartStatus(result)
                "requestMIUIAutostartPermission" -> requestMIUIAutostartPermission(result)
                "handleMIUIOptimization" -> handleMIUIOptimization(result)
                "requestOnePlusAppLocking" -> requestOnePlusAppLocking(result)
                "handleOnePlusEnhancedOptimization" -> handleOnePlusEnhancedOptimization(result)
                "handleSamsungAdaptiveBattery" -> handleSamsungAdaptiveBattery(result)
                "requestSamsungSleepingAppsExemption" -> requestSamsungSleepingAppsExemption(result)
                "handleSamsungDeviceCare" -> handleSamsungDeviceCare(result)
                "handleAsusBackgroundCheck" -> handleAsusBackgroundCheck(result)
                "handleAsusMobileManager" -> handleAsusMobileManager(result)
                "setupGenericAntiKill" -> setupGenericAntiKill(result)
                "startAntiKillForegroundService" -> startAntiKillForegroundService(call, result)
                "setupIntelligentWakeLocks" -> setupIntelligentWakeLocks(call, result)
                "isAntiKillServiceActive" -> isAntiKillServiceActive(result)
                "areWakeLocksActive" -> areWakeLocksActive(result)
                "sendHeartbeat" -> sendHeartbeat(call, result)
                "stopAntiKillService" -> stopAntiKillService(result)
                "getAntiKillStats" -> getAntiKillStats(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("ANTI_KILL_ERROR", "Erro no AntiKillPlugin: ${e.message}", e.toString())
        }
    }

    private fun initializeStats() {
        stats["service_start_time"] = serviceStartTime
        stats["heartbeat_count"] = 0L
        stats["last_heartbeat"] = 0L
        stats["wakelock_active"] = false
        stats["foreground_service_active"] = false
        stats["manufacturer_strategies"] = mutableListOf<String>()
    }

    /**
     * Configura wakelock com tag específica para Huawei EMUI 4
     */
    private fun setHuaweiWakelockTag(call: MethodCall, result: Result) {
        val tag = call.argument<String>("tag") ?: "SentinelAI:AntiKill"
        
        if (Build.MANUFACTURER.equals("Huawei", ignoreCase = true) && 
            Build.VERSION.SDK_INT == Build.VERSION_CODES.M) {
            
            // Usar tag whitelisted para evitar morte pelo HwPFWService
            val whitelistedTag = if (HUAWEI_WHITELISTED_TAGS.contains(tag)) {
                tag
            } else {
                "LocationManagerService" // Tag mais segura
            }
            
            releaseWakeLock()
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, 
                whitelistedTag
            )
            
            wakeLock?.acquire(60 * 60 * 1000L) // 1 hora máximo
            stats["wakelock_active"] = true
            stats["huawei_workaround"] = true
            
            result.success(true)
        } else {
            result.success(false)
        }
    }

    /**
     * Solicita adição à lista de apps protegidos (Huawei/Meizu)
     */
    private fun requestProtectedAppsWhitelist(result: Result) {
        try {
            val intent = when {
                Build.MANUFACTURER.equals("Huawei", ignoreCase = true) -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                        )
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                }
                Build.MANUFACTURER.equals("Meizu", ignoreCase = true) -> {
                    Intent().apply {
                        component = android.content.ComponentName(
                            "com.meizu.safe",
                            "com.meizu.safe.permission.SmartBGAppWhiteListActivity"
                        )
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                }
                else -> null
            }
            
            intent?.let {
                if (isIntentAvailable(it)) {
                    context.startActivity(it)
                    addStrategyToStats("protected_apps_whitelist")
                    result.success(true)
                } else {
                    result.success(false)
                }
            } ?: result.success(false)
            
        } catch (e: Exception) {
            result.error("PROTECTED_APPS_ERROR", e.message, null)
        }
    }

    /**
     * Solicita permissão no startup manager
     */
    private fun requestStartupManagerPermission(result: Result) {
        try {
            val intent = Intent().apply {
                component = when {
                    Build.MANUFACTURER.equals("Huawei", ignoreCase = true) -> {
                        android.content.ComponentName(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                        )
                    }
                    Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true) -> {
                        android.content.ComponentName(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity"
                        )
                    }
                    else -> null
                }
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            intent.component?.let {
                if (isIntentAvailable(intent)) {
                    context.startActivity(intent)
                    addStrategyToStats("startup_manager_permission")
                    result.success(true)
                } else {
                    result.success(false)
                }
            } ?: result.success(false)
            
        } catch (e: Exception) {
            result.error("STARTUP_MANAGER_ERROR", e.message, null)
        }
    }

    /**
     * Detecta presença do PowerGenie da Huawei
     */
    private fun detectPowerGenie(result: Result) {
        try {
            val packageManager = context.packageManager
            val powerGeniePackages = arrayOf(
                "com.huawei.powergenie",
                "com.huawei.android.hwaps"
            )
            
            val hasPowerGenie = powerGeniePackages.any { packageName ->
                try {
                    packageManager.getPackageInfo(packageName, 0)
                    true
                } catch (e: PackageManager.NameNotFoundException) {
                    false
                }
            }
            
            if (hasPowerGenie) {
                stats["powergenie_detected"] = true
                addStrategyToStats("powergenie_detection")
            }
            
            result.success(hasPowerGenie)
        } catch (e: Exception) {
            result.error("POWERGENIE_DETECTION_ERROR", e.message, null)
        }
    }

    /**
     * Solicita pinning do app na MIUI
     */
    private fun requestMIUIAppPinning(result: Result) {
        try {
            // Orientar usuário para fazer pinning manual
            // Não há API programática para isso
            addStrategyToStats("miui_app_pinning")
            result.success(true)
        } catch (e: Exception) {
            result.error("MIUI_PINNING_ERROR", e.message, null)
        }
    }

    /**
     * Verifica status do autostart na MIUI
     */
    private fun checkMIUIAutostartStatus(result: Result) {
        try {
            // Implementação baseada na biblioteca MIUI-autostart
            // Por simplicidade, retornamos "UNKNOWN" aqui
            // Em implementação real, usaríamos reflexão para acessar APIs internas
            result.success("UNKNOWN")
        } catch (e: Exception) {
            result.error("MIUI_AUTOSTART_CHECK_ERROR", e.message, null)
        }
    }

    /**
     * Solicita permissão de autostart na MIUI
     */
    private fun requestMIUIAutostartPermission(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("miui_autostart_permission")
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("MIUI_AUTOSTART_ERROR", e.message, null)
        }
    }

    /**
     * Lida com otimizações da MIUI
     */
    private fun handleMIUIOptimization(result: Result) {
        try {
            // Abrir configurações de otimização MIUI
            val intent = Intent().apply {
                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = Uri.fromParts("package", context.packageName, null)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            context.startActivity(intent)
            addStrategyToStats("miui_optimization")
            result.success(true)
        } catch (e: Exception) {
            result.error("MIUI_OPTIMIZATION_ERROR", e.message, null)
        }
    }

    /**
     * Solicita travamento do app no OnePlus
     */
    private fun requestOnePlusAppLocking(result: Result) {
        try {
            // Orientar usuário para travamento manual na bandeja de recentes
            addStrategyToStats("oneplus_app_locking")
            result.success(true)
        } catch (e: Exception) {
            result.error("ONEPLUS_LOCKING_ERROR", e.message, null)
        }
    }

    /**
     * Lida com otimização avançada do OnePlus
     */
    private fun handleOnePlusEnhancedOptimization(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("oneplus_enhanced_optimization")
                result.success(true)
            } else {
                // Fallback para configurações de bateria
                openBatterySettings()
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("ONEPLUS_OPTIMIZATION_ERROR", e.message, null)
        }
    }

    /**
     * Lida com bateria adaptativa da Samsung
     */
    private fun handleSamsungAdaptiveBattery(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("samsung_adaptive_battery")
                result.success(true)
            } else {
                openBatterySettings()
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("SAMSUNG_ADAPTIVE_BATTERY_ERROR", e.message, null)
        }
    }

    /**
     * Solicita isenção de sleeping apps da Samsung
     */
    private fun requestSamsungSleepingAppsExemption(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.battery.ui.setting.SleepingAppsActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("samsung_sleeping_apps_exemption")
                result.success(true)
            } else {
                openBatterySettings()
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("SAMSUNG_SLEEPING_APPS_ERROR", e.message, null)
        }
    }

    /**
     * Lida com Device Care da Samsung
     */
    private fun handleSamsungDeviceCare(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.cstyleboard.SmartManagerDashBoardActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("samsung_device_care")
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("SAMSUNG_DEVICE_CARE_ERROR", e.message, null)
        }
    }

    /**
     * Lida com Background Check da Asus
     */
    private fun handleAsusBackgroundCheck(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.MainActivity"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("asus_background_check")
                result.success(true)
            } else {
                openBatterySettings()
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("ASUS_BACKGROUND_CHECK_ERROR", e.message, null)
        }
    }

    /**
     * Lida com Mobile Manager da Asus
     */
    private fun handleAsusMobileManager(result: Result) {
        try {
            val intent = Intent().apply {
                component = android.content.ComponentName(
                    "com.asus.mobilemanager",
                    "com.asus.mobilemanager.powersaver.PowerSaverSettings"
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            if (isIntentAvailable(intent)) {
                context.startActivity(intent)
                addStrategyToStats("asus_mobile_manager")
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("ASUS_MOBILE_MANAGER_ERROR", e.message, null)
        }
    }

    /**
     * Configura estratégia genérica anti-kill
     */
    private fun setupGenericAntiKill(result: Result) {
        try {
            // Abrir configurações de otimização de bateria
            openBatteryOptimizationSettings()
            addStrategyToStats("generic_anti_kill")
            result.success(true)
        } catch (e: Exception) {
            result.error("GENERIC_ANTI_KILL_ERROR", e.message, null)
        }
    }

    /**
     * Inicia foreground service anti-kill
     */
    private fun startAntiKillForegroundService(call: MethodCall, result: Result) {
        try {
            createNotificationChannel()
            
            val title = call.argument<String>("title") ?: "Sentinel AI - Proteção Ativa"
            val content = call.argument<String>("content") ?: "Sistema anti-kill ativo"
            val importance = call.argument<String>("importance") ?: "high"
            
            val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(content)
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .setPriority(if (importance == "high") NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setAutoCancel(false)
                .build()
            
            // Iniciar como foreground service
            val serviceIntent = Intent(context, AntiKillForegroundService::class.java)
            serviceIntent.putExtra("notification", notification)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            stats["foreground_service_active"] = true
            result.success(true)
        } catch (e: Exception) {
            result.error("FOREGROUND_SERVICE_ERROR", e.message, null)
        }
    }

    /**
     * Configura wake locks inteligentes
     */
    private fun setupIntelligentWakeLocks(call: MethodCall, result: Result) {
        try {
            val manufacturer = call.argument<String>("manufacturer") ?: ""
            val androidVersion = call.argument<Int>("androidVersion") ?: Build.VERSION.SDK_INT
            
            releaseWakeLock()
            
            val tag = when {
                manufacturer.equals("huawei", ignoreCase = true) && androidVersion == 23 -> {
                    "LocationManagerService" // Tag whitelisted para EMUI 4
                }
                else -> "SentinelAI:AntiKill"
            }
            
            wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, tag)
            wakeLock?.acquire(2 * 60 * 60 * 1000L) // 2 horas máximo
            
            stats["wakelock_active"] = true
            stats["wakelock_tag"] = tag
            
            result.success(true)
        } catch (e: Exception) {
            result.error("WAKELOCK_ERROR", e.message, null)
        }
    }

    /**
     * Verifica se o serviço anti-kill está ativo
     */
    private fun isAntiKillServiceActive(result: Result) {
        val isActive = stats["foreground_service_active"] as? Boolean ?: false
        result.success(isActive)
    }

    /**
     * Verifica se os wake locks estão ativos
     */
    private fun areWakeLocksActive(result: Result) {
        val isActive = wakeLock?.isHeld ?: false
        stats["wakelock_active"] = isActive
        result.success(isActive)
    }

    /**
     * Envia heartbeat
     */
    private fun sendHeartbeat(call: MethodCall, result: Result) {
        val timestamp = call.argument<Long>("timestamp") ?: System.currentTimeMillis()
        val manufacturer = call.argument<String>("manufacturer") ?: ""
        
        heartbeatCount++
        lastHeartbeat = timestamp
        
        stats["heartbeat_count"] = heartbeatCount
        stats["last_heartbeat"] = lastHeartbeat
        stats["manufacturer"] = manufacturer
        
        result.success(true)
    }

    /**
     * Para o serviço anti-kill
     */
    private fun stopAntiKillService(result: Result) {
        try {
            releaseWakeLock()
            
            val serviceIntent = Intent(context, AntiKillForegroundService::class.java)
            context.stopService(serviceIntent)
            
            stats["foreground_service_active"] = false
            stats["wakelock_active"] = false
            
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_SERVICE_ERROR", e.message, null)
        }
    }

    /**
     * Obtém estatísticas do serviço
     */
    private fun getAntiKillStats(result: Result) {
        stats["uptime_ms"] = System.currentTimeMillis() - serviceStartTime
        result.success(stats)
    }

    // Métodos auxiliares

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Sentinel AI Anti-Kill",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantém o Sentinel AI funcionando continuamente"
                setShowBadge(false)
            }
            
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun isIntentAvailable(intent: Intent): Boolean {
        return context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY).isNotEmpty()
    }

    private fun openBatterySettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } else {
            openBatterySettings()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
        stats["wakelock_active"] = false
    }

    private fun addStrategyToStats(strategy: String) {
        val strategies = stats["manufacturer_strategies"] as? MutableList<String> ?: mutableListOf()
        if (!strategies.contains(strategy)) {
            strategies.add(strategy)
            stats["manufacturer_strategies"] = strategies
        }
    }
}

