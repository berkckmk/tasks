package com.steadyprogress.steady_progress

import android.util.Log
import io.grpc.Attributes
import io.grpc.EquivalentAddressGroup
import io.grpc.NameResolver
import io.grpc.NameResolverProvider
import io.grpc.NameResolver.ResolutionResult
import io.grpc.Status
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class Ipv4DnsNameResolverProvider : NameResolverProvider() {
    companion object {
        private const val TAG = "Ipv4DnsResolver"
        private val executor: Executor = Executors.newCachedThreadPool()
    }

    override fun isAvailable(): Boolean = true
    override fun priority(): Int = 10
    override fun getDefaultScheme(): String = "dns"

    override fun newNameResolver(targetUri: URI, args: NameResolver.Args): NameResolver? {
        val scheme = targetUri.scheme
        if (scheme != null && scheme != "dns") {
            return null
        }
        val rawPath = targetUri.authority ?: targetUri.path?.removePrefix("/") ?: targetUri.schemeSpecificPart ?: return null
        val host: String
        val port: Int
        val colonIndex = rawPath.lastIndexOf(':')
        if (colonIndex > 0) {
            host = rawPath.substring(0, colonIndex)
            port = rawPath.substring(colonIndex + 1).toIntOrNull() ?: args.defaultPort
        } else {
            host = rawPath
            port = args.defaultPort
        }

        return object : NameResolver() {
            @Volatile
            private var listener: Listener2? = null

            override fun getServiceAuthority(): String = host

            override fun start(listener: Listener2) {
                this.listener = listener
                resolve()
            }

            override fun refresh() {
                resolve()
            }

            private fun resolve() {
                executor.execute {
                    val currentListener = listener ?: return@execute
                    try {
                        val all = InetAddress.getAllByName(host)
                        val v4 = all.filterIsInstance<Inet4Address>()
                        val chosen = if (v4.isNotEmpty()) v4 else all.toList()
                        Log.i(TAG, "Resolved $host -> ${chosen.joinToString { it.hostAddress ?: "" }}")
                        val socketAddresses = chosen.map { InetSocketAddress(it, port) }
                        val equivalentAddressGroups = socketAddresses.map { EquivalentAddressGroup(it) }
                        val result = ResolutionResult.newBuilder()
                            .setAddresses(equivalentAddressGroups)
                            .setAttributes(Attributes.EMPTY)
                            .build()
                        currentListener.onResult(result)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed resolving $host: ${e.message}", e)
                        currentListener.onError(Status.UNAVAILABLE.withCause(e).withDescription("Unable to resolve host $host"))
                    }
                }
            }

            override fun shutdown() {
                listener = null
            }
        }
    }
}
