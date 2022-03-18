
import click

from norman.consts import DEFAULT_BATCH_SIZE, DEFAULT_DSC_BUF_SIZE, \
    DEFAULT_ETH_PORT, DEFAULT_FPGA, DEFAULT_NB_FALLBACK_QUEUES, \
    DEFAULT_NB_TX_CREDITS, DEFAULT_PKT_BUF_SIZE
from norman.norman_dataplane import NormanDataplane

@click.command()
@click.argument('host')
@click.argument('remote_norman_path')
@click.option('--fpga', default=DEFAULT_FPGA, show_default=True,
              help='Choose the FPGA.')
@click.option('--dsc-buf-size', default=DEFAULT_DSC_BUF_SIZE, show_default=True,
              type=int, help='Buffer size used by each software queue.')
@click.option('--pkt-buf-size', default=DEFAULT_PKT_BUF_SIZE, show_default=True,
              type=int, help='Buffer size used by each software queue.')
@click.option('--tx-credits', default=DEFAULT_NB_TX_CREDITS,
              show_default=True, type=click.IntRange(256, 1000),
              help='Set number of in-flight descriptors allowed (credits).')
@click.option('--eth-port', default=DEFAULT_ETH_PORT, show_default=True,
              type=click.IntRange(0, 1), help='Set Ethernet port to use.')
@click.option('--fallback-queues', default=DEFAULT_NB_FALLBACK_QUEUES,
              show_default=True,
              help='Set number of in-flight descriptors allowed (credits).')
@click.option('--desc-per-pkt/--reactive-desc', default=False,
              show_default=True, help='Use a descriptor per packet or reactive'
              ' descriptors (default).')
@click.option('--enable-rr/--disable-rr', default=False, show_default=True,
              help='Enable/Disable packet round robin to fallback queues.')
@click.option('--batch-size', default=DEFAULT_BATCH_SIZE, show_default=True,
              type=int, help='Number of packets in a batch.')
@click.option('--load-bitstream/--no-load-bitstream', default=True,
              show_default=True,
              help='Enable/Disable packet FPGA bitstream reload.')
def main(host, remote_norman_path, fpga, dsc_buf_size, pkt_buf_size,
         tx_credits, eth_port, fallback_queues, desc_per_pkt, enable_rr,
         batch_size, load_bitstream):

    norman_dp = NormanDataplane(
        fpga, host, remote_norman_path, load_bitstream=load_bitstream,
        ensure_clean=True, setup_sw=True, dsc_buf_size=dsc_buf_size,
        pkt_buf_size=pkt_buf_size, tx_credits=tx_credits,
        ethernet_port=eth_port, fallback_queues=fallback_queues,
        desc_per_pkt=desc_per_pkt, enable_rr=enable_rr,
        sw_batch_size=batch_size, verbose=True
    )

    norman_dp.interactive_shell()


if __name__ == '__main__':
    main()
