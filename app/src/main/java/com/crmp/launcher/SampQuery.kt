package com.crmp.launcher

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.Charset

/** Опрос сервера по стандартному query-протоколу SA-MP (CRMP использует тот же). */
object SampQuery {

    data class Info(
        val hostname: String,
        val gamemode: String,
        val language: String,
        val players: Int,
        val maxPlayers: Int,
        val passworded: Boolean,
        val pingMs: Long
    )

    private val cp1251: Charset = try {
        Charset.forName("windows-1251")
    } catch (e: Exception) {
        Charsets.UTF_8
    }

    fun query(ip: String, port: Int, timeoutMs: Int = 2500): Info? {
        return try {
            DatagramSocket().use { socket ->
                socket.soTimeout = timeoutMs
                val addr = InetAddress.getByName(ip)
                val req = ByteBuffer.allocate(11).order(ByteOrder.LITTLE_ENDIAN)
                req.put("SAMP".toByteArray(Charsets.US_ASCII))
                req.put(addr.address)
                req.putShort(port.toShort())
                req.put('i'.code.toByte())

                val start = System.currentTimeMillis()
                socket.send(DatagramPacket(req.array(), 11, addr, port))

                val buf = ByteArray(2048)
                val resp = DatagramPacket(buf, buf.size)
                socket.receive(resp)
                val ping = System.currentTimeMillis() - start

                val bb = ByteBuffer.wrap(buf, 0, resp.length).order(ByteOrder.LITTLE_ENDIAN)
                bb.position(11)
                val passworded = bb.get().toInt() != 0
                val players = bb.short.toInt() and 0xFFFF
                val maxPlayers = bb.short.toInt() and 0xFFFF
                val hostname = readStr(bb)
                val gamemode = readStr(bb)
                val language = readStr(bb)
                Info(hostname, gamemode, language, players, maxPlayers, passworded, ping)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun readStr(bb: ByteBuffer): String {
        if (bb.remaining() < 4) return ""
        val len = bb.int
        if (len <= 0 || len > bb.remaining()) return ""
        val bytes = ByteArray(len)
        bb.get(bytes)
        return String(bytes, cp1251)
    }
}
