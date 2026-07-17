package MagnetohydrodynamicDriveSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticFluxDensity :> ISQ::MagneticFluxDensityValue;
	
	attribute def ElectricConductivity :> ISQ::ElectricConductivityValue;
	
	attribute def CurrentDensity :> ISQ::CurrentDensityValue;
	
	item def Seawater {
		attribute conductivity : ElectricConductivity;
		attribute velocity : ISQ::VelocityValue;
		attribute density : ISQ::DensityValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def ThrustCommand {
		attribute desiredThrust : ISQ::ForceValue;
	}
	
	item def SystemStatus {
		attribute operationalState : String;
		attribute magneticFieldStrength : MagneticFluxDensity;
		attribute currentFlow : ISQ::ElectricCurrentValue;
	}
	
	part def SuperconductingMagnet {
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute fieldStrength : MagneticFluxDensity;
		port magneticFieldPort {
			out magneticField : MagneticFluxDensity;
		}
		port coolingPort {
			in coolant : ISQ::PowerValue;
		}
		port powerPort {
			in electricalPower : ElectricalPower;
		}
	}
	
	part def ElectrodeAssembly {
		attribute polarity : String;
		attribute surfaceArea : ISQ::AreaValue;
		port electricalPort {
			in power : ElectricalPower;
			out currentDensity : CurrentDensity;
		}
		port seawaterPort {
			inout seawater : Seawater;
		}
	}
	
	part def ThrustChannel {
		attribute crossSection : ISQ::AreaValue;
		attribute channelLength : ISQ::LengthValue;
		port inletPort {
			in seawaterIn : Seawater;
		}
		port outletPort {
			out seawaterOut : Seawater;
			out thrust : ISQ::ForceValue;
		}
		port magneticPort {
			in magneticField : MagneticFluxDensity;
		}
		port electrodePort {
			in currentDensity : CurrentDensity;
		}
	}
	
	part def PowerSupply {
		attribute maxPowerOutput : ISQ::PowerValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		port powerInput {
			in primaryPower : ISQ::PowerValue;
		}
		port powerOutput {
			out electricalPower : ElectricalPower;
		}
	}
	
	part def CryogenicCoolingSystem {
		attribute coolingCapacity : ISQ::PowerValue;
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		port coolantCirculation {
			out coolingPower : ISQ::PowerValue;
		}
		port heatLoad {
			in thermalLoad : ISQ::PowerValue;
		}
	}
	
	part def ControlUnit {
		attribute targetThrust : ISQ::ForceValue;
		port commandInput {
			in thrustCommand : ThrustCommand;
		}
		port statusOutput {
			out systemStatus : SystemStatus;
		}
		port powerControl {
			out powerCommand : ElectricalPower;
		}
		port magnetControl {
			out magnetCommand : ElectricalPower;
		}
		port feedbackInput {
			in measuredThrust : ISQ::ForceValue;
			in measuredVelocity : ISQ::VelocityValue;
		}
	}
	
	part def FlowSensor {
		port sensingPort {
			in seawater : Seawater;
		}
		port outputPort {
			out measuredVelocity : ISQ::VelocityValue;
		}
	}
	
	part def ThrustSensor {
		port sensingPort {
			in thrust : ISQ::ForceValue;
		}
		port outputPort {
			out measuredThrust : ISQ::ForceValue;
		}
	}
	
	action def EstablishMagneticField {
		in coolingPower : ISQ::PowerValue;
		in electricalPower : ElectricalPower;
		out magneticField : MagneticFluxDensity;
	}
	
	action def ApplyElectricCurrent {
		in voltage : ISQ::ElectricPotentialValue;
		in seawaterConductivity : ElectricConductivity;
		out currentDensity : CurrentDensity;
	}
	
	action def GenerateLorentzForce {
		in currentDensity : CurrentDensity;
		in magneticField : MagneticFluxDensity;
		in seawaterDensity : ISQ::DensityValue;
		out thrustForce : ISQ::ForceValue;
	}
	
	action def AccelerateSeawater {
		in thrustForce : ISQ::ForceValue;
		in inletVelocity : ISQ::VelocityValue;
		out outletVelocity : ISQ::VelocityValue;
	}
	
	action def MonitorPerformance {
		in measuredThrust : ISQ::ForceValue;
		in measuredVelocity : ISQ::VelocityValue;
		out systemStatus : SystemStatus;
	}
	
	action def ProvidePropulsion {
		in thrustCommand : ThrustCommand;
		in ambientSeawater : Seawater;
		out propulsiveThrust : ISQ::ForceValue;
		out exhaustVelocity : ISQ::VelocityValue;
		
		first start;
		
		action initializeCooling {
			doc /* Activate cryogenic cooling to maintain superconducting state */
			out coolingPower : ISQ::PowerValue;
		}
		then initializeCooling;
		
		flow initializeCooling.coolingPower to establishField.coolingPower;
		
		action establishField : EstablishMagneticField {
			in coolingPower : ISQ::PowerValue;
			in electricalPower : ElectricalPower;
			out magneticField : MagneticFluxDensity;
		}
		then establishField;
		
		flow establishField.magneticField to generateForce.magneticField;
		
		action applyCurrent : ApplyElectricCurrent {
			in voltage : ISQ::ElectricPotentialValue;
			in seawaterConductivity : ElectricConductivity = ambientSeawater.conductivity;
			out currentDensity : CurrentDensity;
		}
		then applyCurrent;
		
		flow applyCurrent.currentDensity to generateForce.currentDensity;
		
		action generateForce : GenerateLorentzForce {
			in currentDensity : CurrentDensity;
			in magneticField : MagneticFluxDensity;
			in seawaterDensity : ISQ::DensityValue = ambientSeawater.density;
			out thrustForce : ISQ::ForceValue;
		}
		then generateForce;
		
		flow generateForce.thrustForce to accelerateFluid.thrustForce;
		
		action accelerateFluid : AccelerateSeawater {
			in thrustForce : ISQ::ForceValue;
			in inletVelocity : ISQ::VelocityValue = ambientSeawater.velocity;
			out outletVelocity : ISQ::VelocityValue;
		}
		then accelerateFluid;
		
		flow accelerateFluid.outletVelocity to monitorPerformance.measuredVelocity;
		flow generateForce.thrustForce to monitorPerformance.measuredThrust;
		
		action monitorPerformance : MonitorPerformance {
			in measuredThrust : ISQ::ForceValue;
			in measuredVelocity : ISQ::VelocityValue;
			out systemStatus : SystemStatus;
		}
		then monitorPerformance;
		
		flow generateForce.thrustForce to propulsiveThrust;
		flow accelerateFluid.outletVelocity to exhaustVelocity;
		
		then done;
	}
	
	part def MHDDriveSystem {
		part controller : ControlUnit {
			attribute :>> targetThrust : ISQ::ForceValue = 15000[SI::N];
		}
		
		part powerSupply : PowerSupply {
			attribute :>> maxPowerOutput : ISQ::PowerValue = 1000[SI::kW];
			attribute :>> outputVoltage : ISQ::ElectricPotentialValue = 500[SI::V];
		}
		
		part coolingSystem : CryogenicCoolingSystem {
			attribute :>> coolingCapacity : ISQ::PowerValue = 100[SI::kW];
			attribute :>> operatingTemperature : ISQ::ThermodynamicTemperatureValue = 4[SI::K];
		}
		
		part portMagnet : SuperconductingMagnet {
			attribute :>> operatingTemperature : ISQ::ThermodynamicTemperatureValue = 4[SI::K];
			attribute :>> fieldStrength : MagneticFluxDensity;
		}
		
		part starboardMagnet : SuperconductingMagnet {
			attribute :>> operatingTemperature : ISQ::ThermodynamicTemperatureValue = 4[SI::K];
			attribute :>> fieldStrength : MagneticFluxDensity;
		}
		
		part anodeAssembly : ElectrodeAssembly {
			attribute :>> polarity = "positive";
			attribute :>> surfaceArea : ISQ::AreaValue = 1.5[SI::'m^2'];
		}
		
		part cathodeAssembly : ElectrodeAssembly {
			attribute :>> polarity = "negative";
			attribute :>> surfaceArea : ISQ::AreaValue = 1.5[SI::'m^2'];
		}
		
		part thrustChannel : ThrustChannel {
			attribute :>> crossSection : ISQ::AreaValue = 3[SI::'m^2'];
			attribute :>> channelLength : ISQ::LengthValue = 6[SI::m];
		}
		
		part flowSensor : FlowSensor;
		
		part thrustSensor : ThrustSensor;
		
		connect powerSupply.powerOutput to controller.powerControl;
		connect powerSupply.powerOutput to portMagnet.powerPort;
		connect powerSupply.powerOutput to starboardMagnet.powerPort;
		connect powerSupply.powerOutput to anodeAssembly.electricalPort;
		connect powerSupply.powerOutput to cathodeAssembly.electricalPort;
		
		connect coolingSystem.coolantCirculation to portMagnet.coolingPort;
		connect coolingSystem.coolantCirculation to starboardMagnet.coolingPort;
		
		connect portMagnet.magneticFieldPort to thrustChannel.magneticPort;
		connect starboardMagnet.magneticFieldPort to thrustChannel.magneticPort;
		
		connect anodeAssembly.electricalPort to thrustChannel.electrodePort;
		connect cathodeAssembly.electricalPort to thrustChannel.electrodePort;
		
		connect thrustChannel.outletPort to flowSensor.sensingPort;
		connect thrustChannel.outletPort to thrustSensor.sensingPort;
		
		connect flowSensor.outputPort to controller.feedbackInput;
		connect thrustSensor.outputPort to controller.feedbackInput;
		
		perform action operateDrive[*] ordered references propulsionCycle;
	}
	
	part mhdVessel : MHDDriveSystem;
	
	action propulsionCycle : ProvidePropulsion {
		in thrustCommand : ThrustCommand;
		in ambientSeawater : Seawater;
		out propulsiveThrust : ISQ::ForceValue;
		out exhaustVelocity : ISQ::VelocityValue;
	}
	
	state def DriveOperationalStates {
		entry; then idle;
		
		state idle {
			doc /* System is powered but not generating thrust */
		}
		
		state initializing {
			doc /* Cooling system activating and magnets energizing */
		}
		
		state operational {
			doc /* System generating thrust within normal parameters */
		}
		
		state degraded {
			doc /* System operating with reduced performance */
		}
		
		state shutdown {
			doc /* System powering down safely */
		}
		
		transition idleToInit
			first idle
			accept thrustCommand : ThrustCommand
			then initializing;
		
		transition initToOperational
			first initializing
			then operational;
		
		transition operationalToDegraded
			first operational
			then degraded;
		
		transition degradedToOperational
			first degraded
			then operational;
		
		transition operationalToShutdown
			first operational
			accept thrustCommand : ThrustCommand
			then shutdown;
		
		transition shutdownToIdle
			first shutdown
			then idle;
	}
	
	state driveStateMachine : DriveOperationalStates for MHDDriveSystem;
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement primaryFunction : FunctionalRequirement {
		doc /* The MHD Drive System shall generate propulsive thrust by accelerating seawater 
		     through electromagnetic forces without mechanical moving parts in the propulsion stream. */
		
		subject mhdVessel : MHDDriveSystem;
		
		require constraint electromagneticPropulsion {
			doc /* Thrust generation shall result from Lorentz force acting on conductive seawater 
			     in the presence of perpendicular magnetic and electric fields. */
		}
	}
	
	requirement thrustPerformance : PerformanceRequirement {
		doc /* The system shall generate minimum sustained thrust of 10 kilonewtons. */
		
		refines primaryFunction;
		
		require constraint minimumThrust {
			doc /* Propulsive thrust shall be at least 10000 N during operational state. */
		}
	}
	
	requirement magneticFieldStrength : PerformanceRequirement {
		doc /* Superconducting magnets shall maintain magnetic flux density of at least 5 Tesla. */
		
		refines primaryFunction;
		
		require constraint fieldStrengthMinimum {
			doc /* Magnetic flux density shall be >= 5 T during operational state. */
		}
	}
	
	requirement cryogenicOperation : SafetyRequirement {
		doc /* Cooling system shall maintain superconducting magnets below critical temperature. */
		
		refines primaryFunction;
		
		require constraint temperatureLimit {
			doc /* Magnet operating temperature shall remain below 10 Kelvin. */
		}
		
		assume constraint coolingAvailable {
			doc /* Cryogenic cooling capacity is sufficient for continuous operation. */
		}
	}
	
	requirement electricalPower : PerformanceRequirement {
		doc /* Power supply shall provide stable high-current electrical power. */
		
		refines primaryFunction;
		
		require constraint powerCapacity {
			doc /* Power supply shall deliver at least 1 MW continuous power. */
		}
		
		require constraint voltageStability {
			doc /* Output voltage variation shall not exceed 5 percent. */
		}
	}
	
	requirement seawaterConductivity : FunctionalRequirement {
		doc /* System shall operate in seawater with minimum electrical conductivity. */
		
		refines primaryFunction;
		
		assume constraint conductivityMinimum {
			doc /* Seawater electrical conductivity shall be at least 4 S/m. */
		}
	}
	
	mhdVessel satisfies primaryFunction, thrustPerformance, magneticFieldStrength, 
	                     cryogenicOperation, electricalPower, seawaterConductivity;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MagnetohydrodynamicDriveSystem::*;

    part testSubject : SuperconductingMagnet {
        exhibit state sm : DriveOperationalStates;
    }

    action orchestrator {
        attribute testCoolingPower : ISQ::PowerValue;
        item testElectricalPower : ElectricalPower {
            attribute voltage : ISQ::ElectricPotentialValue;
            attribute current : ISQ::ElectricCurrentValue;
        }
        action establishFieldProbe : EstablishMagneticField {
            in coolingPower = testCoolingPower;
            in electricalPower = testElectricalPower;
        }
        first establishFieldProbe;
    }
}
