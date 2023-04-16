import click

from enso.consts import (
    DEFAULT_DSC_BUF_SIZE,
    DEFAULT_ETH_PORT,
    DEFAULT_FPGA,
    DEFAULT_NB_FALLBACK_QUEUES,
    DEFAULT_NB_TX_CREDITS,
    DEFAULT_PKT_BUF_SIZE,
)
from enso.enso_nic import EnsoNic


@click.command()
@click.argument("enso_path")
@click.option(
    "--host",
    default="localhost",
    show_default=True,
    help="Host to connect to run Ensō on.",
)
@click.option(
    "--fpga", default=DEFAULT_FPGA, show_default=True, help="Choose the FPGA."
)
@click.option(
    "--dsc-buf-size",
    default=DEFAULT_DSC_BUF_SIZE,
    show_default=True,
    type=int,
    help="Buffer size used by each software descriptor buffer.",
)
@click.option(
    "--pkt-buf-size",
    default=DEFAULT_PKT_BUF_SIZE,
    show_default=True,
    type=int,
    help="Buffer size used by each software packet buffer.",
)
@click.option(
    "--tx-credits",
    default=DEFAULT_NB_TX_CREDITS,
    show_default=True,
    type=click.IntRange(256, 1000),
    help="Set number of in-flight descriptors allowed (credits).",
)
@click.option(
    "--eth-port",
    default=DEFAULT_ETH_PORT,
    show_default=True,
    type=click.IntRange(0, 1),
    help="Set Ethernet port to use.",
)
@click.option(
    "--fallback-queues",
    default=DEFAULT_NB_FALLBACK_QUEUES,
    show_default=True,
    help="Set number of fallback queues. Fallback queues are used to"
    " catch packets that are not directed to any of the regular"
    " queues. If the number of fallback queues is set to 0, packets"
    " that fail to match any rule are discarded.",
)
@click.option(
    "--desc-per-pkt/--reactive-desc",
    default=False,
    show_default=True,
    help="Use a descriptor per packet or reactive" " descriptors (default).",
)
@click.option(
    "--enable-rr/--disable-rr",
    default=False,
    show_default=True,
    help="Enable/Disable packet round robin to fallback queues.",
)
@click.option(
    "--latency-opt/--throughput-opt",
    default=False,
    show_default=True,
    help="Optimize for throughput/latency.",
)
@click.option(
    "--load-bitstream/--no-load-bitstream",
    default=True,
    show_default=True,
    help="Enable/Disable packet FPGA bitstream reload.",
)
def main(
    host,
    enso_path,
    fpga,
    dsc_buf_size,
    pkt_buf_size,
    tx_credits,
    eth_port,
    fallback_queues,
    desc_per_pkt,
    enable_rr,
    latency_opt,
    load_bitstream,
):

    enso_nic = EnsoNic(
        fpga,
        enso_path,
        host_name=host,
        load_bitstream=load_bitstream,
        ensure_clean=True,
        setup_sw=True,
        dsc_buf_size=dsc_buf_size,
        pkt_buf_size=pkt_buf_size,
        tx_credits=tx_credits,
        ethernet_port=eth_port,
        fallback_queues=fallback_queues,
        desc_per_pkt=desc_per_pkt,
        enable_rr=enable_rr,
        latency_opt=latency_opt,
        verbose=True,
        log_file=True,
    )

    enso_nic.interactive_shell()


if __name__ == "__main__":
    main()
