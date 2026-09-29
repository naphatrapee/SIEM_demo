"""Syslog listener (UDP + TCP) on 5514 inside the container (host maps 514 -> 5514)."""
import asyncio
import os

from ingest.normalizers import normalize_syslog

PORT = 5514
TENANT = os.getenv("DEFAULT_TENANT", "demoA")
queue: asyncio.Queue = asyncio.Queue()


class UDPHandler(asyncio.DatagramProtocol):
    def datagram_received(self, data, addr):
        queue.put_nowait(data.decode(errors="ignore").strip())


async def tcp_handler(reader, writer):
    while line := await reader.readline():
        queue.put_nowait(line.decode(errors="ignore").strip())
    writer.close()


async def batch_writer():
    # TODO: drain queue in batches (e.g. 200 events / 1s) and INSERT into Postgres
    while True:
        line = await queue.get()
        event = normalize_syslog(line, TENANT)
        print("received:", event["source"], event["src_ip"], flush=True)


async def main():
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(UDPHandler, local_addr=("0.0.0.0", PORT))
    await asyncio.start_server(tcp_handler, "0.0.0.0", PORT)
    print(f"syslog listening on {PORT} (udp+tcp)", flush=True)
    await batch_writer()


if __name__ == "__main__":
    asyncio.run(main())
