using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace CrmpLauncher
{
    internal sealed class ServerInfo
    {
        public string Hostname, Gamemode, Language;
        public int Players, MaxPlayers;
        public bool Passworded;
        public long PingMs;
    }

    /// <summary>Опрос сервера по query-протоколу SA-MP (CRMP использует тот же).</summary>
    internal static class SampQuery
    {
        private static readonly Encoding Cp1251 = Encoding.GetEncoding(1251);

        public static ServerInfo Query(string ip, int port, int timeoutMs = 2500)
        {
            try
            {
                var addr = IPAddress.Parse(ip);
                using (var udp = new UdpClient())
                {
                    udp.Client.ReceiveTimeout = timeoutMs;
                    var req = new byte[11];
                    Encoding.ASCII.GetBytes("SAMP").CopyTo(req, 0);
                    addr.GetAddressBytes().CopyTo(req, 4);
                    req[8] = (byte)(port & 0xFF);
                    req[9] = (byte)(port >> 8);
                    req[10] = (byte)'i';

                    var sw = Stopwatch.StartNew();
                    udp.Send(req, req.Length, new IPEndPoint(addr, port));
                    var remote = new IPEndPoint(IPAddress.Any, 0);
                    byte[] resp = udp.Receive(ref remote);
                    sw.Stop();

                    using (var br = new BinaryReader(new MemoryStream(resp)))
                    {
                        br.ReadBytes(11);
                        var info = new ServerInfo();
                        info.Passworded = br.ReadByte() != 0;
                        info.Players = br.ReadUInt16();
                        info.MaxPlayers = br.ReadUInt16();
                        info.Hostname = ReadStr(br);
                        info.Gamemode = ReadStr(br);
                        info.Language = ReadStr(br);
                        info.PingMs = sw.ElapsedMilliseconds;
                        return info;
                    }
                }
            }
            catch
            {
                return null;
            }
        }

        private static string ReadStr(BinaryReader br)
        {
            if (br.BaseStream.Length - br.BaseStream.Position < 4) return "";
            int len = br.ReadInt32();
            if (len <= 0 || len > br.BaseStream.Length - br.BaseStream.Position) return "";
            return Cp1251.GetString(br.ReadBytes(len));
        }
    }
}
