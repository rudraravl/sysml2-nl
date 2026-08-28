package 'Conductive Polymer System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	attribute def Temperature :> Real;
	attribute def Humidity :> Real;
	attribute def Voltage :> Real;
	attribute def Current :> Real;
	attribute def Conductivity :> Real;
	attribute def ChainLength :> Real;
	attribute def DopingConcentration :> Real;

	enum def OperationalState {
		enum undoped;
		enum lightlyDoped;
		enum heavilyDoped;
		enum degraded;
	}

	enum def DopingLevel {
		enum none;
		enum light;
		enum heavy;
	}

	item def Dopant {
		attribute concentration : DopingConcentration;
	}

	item def ChargeCarrier {
		attribute mobility : Real;
		attribute density : Real;
	}

	port def DopantOutPort {
		out item dopant : Dopant;
	}

	port def DopantInPort {
		in item dopant : Dopant;
	}

	port def EnvOutPort {
		out temperature : Temperature;
		out humidity : Humidity;
	}

	port def EnvInPort {
		in temperature : Temperature;
		in humidity : Humidity;
	}

	port def ElectrodePort {
		in voltage : Voltage;
		out current : Current;
	}

	port def CarrierOutPort {
		out item carriers : ChargeCarrier;
	}

	port def CarrierInPort {
		in item carriers : ChargeCarrier;
	}

	part def PolymerChain {
		attribute chainLength : ChainLength;
		attribute degreeOfOrder : Real;
		attribute operationalState : OperationalState;
		port dopantInput : DopantInPort;
		port envInput : EnvInPort;
		port positiveTerminal : ElectrodePort;
		port negativeTerminal : ElectrodePort;
		port carrierOutput : CarrierOutPort;
	}

	part def DopingAgent {
		attribute dopingLevel : DopingLevel;
		attribute concentration : DopingConcentration;
		port dopingOutput : DopantOutPort;
	}

	state def EnvControlState {
		initial state monitoring;
		state regulating;
		transition from monitoring to regulating
			when temperature != targetTemperature or humidity != targetHumidity;
		transition from regulating to monitoring
			when temperature == targetTemperature and humidity == targetHumidity;
	}

	part def EnvironmentalController {
		attribute temperature : Temperature;
		attribute humidity : Humidity;
		attribute targetTemperature : Temperature;
		attribute targetHumidity : Humidity;
		port envOutput : EnvOutPort;
		exhibit state envControlState : EnvControlState;
	}

	part def Electrode {
		attribute appliedVoltage : Voltage;
		attribute measuredCurrent : Current;
		port electrodePort : ~ElectrodePort;
	}

	part def ConductionMechanism {
		attribute conductivity : Conductivity;
		port carrierInput : CarrierInPort;
		port voltageInput : ~ElectrodePort;
		port currentOutput : ElectrodePort;
	}

	state def MaterialState {
		initial state undoped;
		state lightlyDoped;
		state heavilyDoped;
		state degraded;
		transition from undoped to lightlyDoped
			when dopingLevel == DopingLevel::light;
		transition from undoped to heavilyDoped
			when dopingLevel == DopingLevel::heavy;
		transition from lightlyDoped to heavilyDoped
			when dopingLevel == DopingLevel::heavy;
		transition from undoped to degraded
			when envTemperature > 350 or envHumidity > 80;
		transition from lightlyDoped to degraded
			when envTemperature > 350 or envHumidity > 80;
		transition from heavilyDoped to degraded
			when envTemperature > 350 or envHumidity > 80;
	}

	action def OperationalProcess {
		first start;
		then action initializePolymer;
		then action applyDopant;
		then action stabilizeEnvironment;
		then action applyVoltage;
		then done;
	}

	part def ConductivePolymerSystem {
		attribute conductivity : Conductivity;
		attribute operationalState : OperationalState;
		attribute dopingLevel : DopingLevel;
		attribute envTemperature : Temperature;
		attribute envHumidity : Humidity;

		part polymerChain : PolymerChain;
		part dopingAgent : DopingAgent;
		part environmentalController : EnvironmentalController;
		part positiveElectrode : Electrode;
		part negativeElectrode : Electrode;
		part conductionMechanism : ConductionMechanism;

		connection dopingConnection
			connect dopingAgent.dopingOutput to polymerChain.dopantInput;
		connection envConnection
			connect environmentalController.envOutput to polymerChain.envInput;
		connection positiveElectrodeConnection
			connect positiveElectrode.electrodePort to polymerChain.positiveTerminal;
		connection negativeElectrodeConnection
			connect negativeElectrode.electrodePort to polymerChain.negativeTerminal;
		connection carrierConnection
			connect polymerChain.carrierOutput to conductionMechanism.carrierInput;
		connection mechanismVoltageConnection
			connect polymerChain.positiveTerminal to conductionMechanism.voltageInput;
		connection mechanismCurrentConnection
			connect conductionMechanism.currentOutput to positiveElectrode.electrodePort;

		exhibit state materialState : MaterialState;
		perform operationalProcess : OperationalProcess;
	}

	requirement def ConductivityRequirement {
		subject conductivePolymer : ConductivePolymerSystem;
		objective {
			doc /* The conductive polymer must achieve sufficient conductivity when heavily doped */
			assert constraint { conductivePolymer.conductivity > 1000.0 }
		}
	}

	requirement def EnvironmentalStabilityRequirement {
		subject controller : EnvironmentalController;
		objective {
			doc /* The environmental controller must maintain temperature and humidity within specified bounds */
			assert constraint { controller.temperature >= 250 and controller.temperature <= 350 }
			assert constraint { controller.humidity >= 0 and controller.humidity <= 60 }
		}
	}

	requirement def DopingProcessRequirement {
		subject system : ConductivePolymerSystem;
		objective {
			doc /* The system must not enter degraded state under normal operating conditions */
			assert constraint { system.operationalState != OperationalState::degraded }
		}
	}
}
