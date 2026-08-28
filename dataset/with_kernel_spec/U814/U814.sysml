package PMTSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	item def Photon;
	item def Electron;
	item def OutputPulse;

	attribute def PhotonArrived;
	attribute def NoLight;
	attribute def OverLight;
	attribute def Reset;

	port def PhotonInPort { in photons : Photon; }
	port def PhotonOutPort { out photons : Photon; }
	port def ElectronInPort { in electrons : Electron; }
	port def ElectronOutPort { out electrons : Electron; }
	port def PulseOutPort { out pulse : OutputPulse; }
	port def BiasInPort { in voltage : ElectricPotentialValue; }
	port def BiasOutPort { out voltage : ElectricPotentialValue; }

	part def VacuumEnvelope {
		attribute material : String := "Borosilicate Glass";
	}

	part def UVWindow {
		attribute transmissionBand : String := "UV-Visible";
		port lightIn : PhotonInPort;
		port lightOut : PhotonOutPort;
	}

	part def Photocathode {
		attribute quantumEfficiency : Real := 0.25;
		port lightIn : PhotonInPort;
		port electronsOut : ElectronOutPort;
		port bias : BiasInPort;
		action emitPhotoelectrons {
			in incidentPhotons : Photon;
			out primaryElectrons : Electron;
		}
	}

	part def Dynode {
		attribute stageNumber : Integer;
		attribute secondaryEmissionRatio : Real := 4.0;
		port electronsIn : ElectronInPort;
		port electronsOut : ElectronOutPort;
		port bias : BiasInPort;
		action emitSecondaryElectrons {
			in incidentElectrons : Electron;
			out secondaryElectrons : Electron;
		}
	}

	part def DynodeChain {
		attribute stageCount : Integer := 10;
		part dynode1 : Dynode { attribute stageNumber = 1; }
		part dynode2 : Dynode { attribute stageNumber = 2; }
		part dynode3 : Dynode { attribute stageNumber = 3; }
		part dynode4 : Dynode { attribute stageNumber = 4; }
		part dynode5 : Dynode { attribute stageNumber = 5; }
		part dynode6 : Dynode { attribute stageNumber = 6; }
		part dynode7 : Dynode { attribute stageNumber = 7; }
		part dynode8 : Dynode { attribute stageNumber = 8; }
		part dynode9 : Dynode { attribute stageNumber = 9; }
		part dynode10 : Dynode { attribute stageNumber = 10; }

		port chainIn : ElectronInPort;
		port chainOut : ElectronOutPort;
		port bias1 : BiasInPort;
		port bias2 : BiasInPort;
		port bias3 : BiasInPort;
		port bias4 : BiasInPort;
		port bias5 : BiasInPort;
		port bias6 : BiasInPort;
		port bias7 : BiasInPort;
		port bias8 : BiasInPort;
		port bias9 : BiasInPort;
		port bias10 : BiasInPort;

		connect chainIn to dynode1.electronsIn;
		connect dynode1.electronsOut to dynode2.electronsIn;
		connect dynode2.electronsOut to dynode3.electronsIn;
		connect dynode3.electronsOut to dynode4.electronsIn;
		connect dynode4.electronsOut to dynode5.electronsIn;
		connect dynode5.electronsOut to dynode6.electronsIn;
		connect dynode6.electronsOut to dynode7.electronsIn;
		connect dynode7.electronsOut to dynode8.electronsIn;
		connect dynode8.electronsOut to dynode9.electronsIn;
		connect dynode9.electronsOut to dynode10.electronsIn;
		connect dynode10.electronsOut to chainOut;

		action amplify {
			in electronsIn : Electron;
			out electronsOut : Electron;
		}
	}

	part def Anode {
		port electronsIn : ElectronInPort;
		port pulseOut : PulseOutPort;
		port bias : BiasInPort;
		action collectElectrons {
			in collectedElectrons : Electron;
			out pulse : OutputPulse;
		}
	}

	part def HighVoltageSupply {
		attribute outputVoltage : ElectricPotentialValue := 1000;
		port hvOut : BiasOutPort;
	}

	part def VoltageDivider {
		port hvIn : BiasInPort;
		port cathodeBias : BiasOutPort;
		port tap1 : BiasOutPort;
		port tap2 : BiasOutPort;
		port tap3 : BiasOutPort;
		port tap4 : BiasOutPort;
		port tap5 : BiasOutPort;
		port tap6 : BiasOutPort;
		port tap7 : BiasOutPort;
		port tap8 : BiasOutPort;
		port tap9 : BiasOutPort;
		port tap10 : BiasOutPort;
		port anodeBias : BiasOutPort;
	}

	part def PMT {
		part envelope : VacuumEnvelope;
		part window : UVWindow;
		part photocathode : Photocathode;
		part dynodeChain : DynodeChain;
		part anode : Anode;
		part hvSupply : HighVoltageSupply;
		part divider : VoltageDivider;

		port lightIn : PhotonInPort;
		port pulseOut : PulseOutPort;

		connect lightIn to window.lightIn;
		connect window.lightOut to photocathode.lightIn;
		connect photocathode.electronsOut to dynodeChain.chainIn;
		connect dynodeChain.chainOut to anode.electronsIn;
		connect anode.pulseOut to pulseOut;

		connect hvSupply.hvOut to divider.hvIn;
		connect divider.cathodeBias to photocathode.bias;
		connect divider.tap1 to dynodeChain.bias1;
		connect divider.tap2 to dynodeChain.bias2;
		connect divider.tap3 to dynodeChain.bias3;
		connect divider.tap4 to dynodeChain.bias4;
		connect divider.tap5 to dynodeChain.bias5;
		connect divider.tap6 to dynodeChain.bias6;
		connect divider.tap7 to dynodeChain.bias7;
		connect divider.tap8 to dynodeChain.bias8;
		connect divider.tap9 to dynodeChain.bias9;
		connect divider.tap10 to dynodeChain.bias10;
		connect divider.anodeBias to anode.bias;

		action detectPhoton {
			in photon : Photon;
			out pulse : OutputPulse;
		}
	}

	state def PMTOperation {
		part pmt : PMT;
		first state idle;
		accept PhotonArrived then detecting;
		state detecting {
			accept NoLight then idle;
			accept OverLight then saturated;
		}
		state saturated {
			accept Reset then idle;
		}
	}

	requirement def MinGainRequirement {
		subject pmt : PMT;
		objective {
			doc "The PMT shall amplify a single photoelectron into a cascade of over a million electrons.";
		}
	}

	requirement def VacuumEnvelopeRequirement {
		subject envelope : VacuumEnvelope;
		objective {
			doc "The vacuum envelope shall be made of borosilicate glass and maintain vacuum.";
		}
	}

	requirement def DynodeChainRequirement {
		subject dynodeChain : DynodeChain;
		objective {
			doc "The dynode chain shall consist of ten dynodes each held at a progressively higher voltage.";
		}
	}

	requirement def OverlightProtectionRequirement {
		subject pmt : PMT;
		objective {
			doc "The system shall enter a saturated state when incoming light is too intense.";
		}
	}

	requirement def UVWindowRequirement {
		subject window : UVWindow;
		objective {
			doc "A UV-transmitting window shall allow photons to enter and strike the photocathode.";
		}
	}

	requirement def VoltageDividerRequirement {
		subject divider : VoltageDivider;
		objective {
			doc "The voltage divider shall distribute incrementally higher voltages to each dynode.";
		}
	}

	part pmtAssembly : PMT;
}
