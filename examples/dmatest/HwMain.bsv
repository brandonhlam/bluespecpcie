import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;

import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;

import DMASplitter::*;

interface HwMainIfc;
endinterface

module mkHwMain#(PcieUserIfc pcie) 
	(HwMainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Clock pcieclk = pcie.user_clk;
	Reset pcierst = pcie.user_rst;

	//DMASplitterIfc#(4) dma <- mkDMASplitter(pcie);

	Reg#(Bit#(32)) wordWriteLeft <- mkReg(0, clocked_by pcieclk, reset_by pcierst);
	Reg#(Bit#(32)) wordWriteReq <- mkReg(0, clocked_by pcieclk, reset_by pcierst);

	rule getCmd ( wordWriteLeft == 0 );
		let w <- pcie.dataReceive;
		let a = w.addr;
		let d = w.data;
		let off = (a>>2);
		if ( off == 0 ) begin
			wordWriteLeft <= d;
			wordWriteReq <= d;
			pcie.dmaWriteReq( 0, truncate(d), 0 ); // offset, words, tag
		end
	endrule

	rule sendDMAData ( wordWriteLeft > 0 );
		pcie.dmaWriteData({wordWriteLeft,wordWriteLeft,wordWriteLeft,wordWriteLeft}, 0);
		wordWriteLeft <= wordWriteLeft - 1;
	endrule

	rule readStat;
		let r <- pcie.dataReq;
		let a = r.addr;

		// PCIe IO is done at 4 byte granularities
		// lower 2 bits are always zero
		let offset = (a>>2);
		if ( offset == 0 ) begin
			pcie.dataSend(r, wordWriteLeft);
		end else if ( offset == 1 ) begin
			pcie.dataSend(r, wordWriteReq);
		end else begin
			pcie.dataSend(r, pcie.debug_data);
		end
	endrule

endmodule