package StirlingEngineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ThermalEfficiency :> Real;
	attribute def CyclePhase;
	
	item def ThermalEnergy {
		attribute heatFlowRate : HeatFlowRateValue;
		attribute temperature : TemperatureValue;
	}
	
	item def MechanicalPower {
		attribute torque : TorqueValue;
		attribute angularVelocity : AngularVelocityValue;
		attribute power : PowerValue = torque * angularVelocity;
	}
	
	port def ThermalPort {
		inout thermalFlow : ThermalEnergy;
	}
	
	port def MechanicalPort {
		out mechanicalOutput : MechanicalPower;
	}
	
	part def HeatSource {
		attribute sourceTemperature : TemperatureValue = 873 [K];
		port thermalOutput : ThermalPort;
	}
	
	part def HeatSink {
		attribute sinkTemperature : TemperatureValue = 303 [K];
		port thermalInput : ThermalPort;
	}
	
	part def ExpansionChamber {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		port heatInput : ThermalPort;
		port gasOutput : ThermalPort;
	}
	
	part def CompressionChamber {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		port gasInput : ThermalPort;
		port heatOutput : ThermalPort;
	}
	
	part def Regenerator {
		attribute storedHeat : EnergyValue;
		attribute efficiency : ThermalEfficiency = 0.85;
		port hotSide : ThermalPort;
		port coldSide : ThermalPort;
	}
	
	part def PowerPiston {
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
		attribute force : ForceValue;
		port mechanicalOutput : MechanicalPort;
	}
	
	part def DisplacerPiston {
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
	}
	
	part def Crankshaft {
		attribute angularPosition : ISQ::AngleValue;
		attribute rotationSpeed : AngularVelocityValue;
		port shaftOutput : MechanicalPort;
	}
	
	part def Flywheel {
		attribute momentOfInertia : MomentOfInertiaValue;
		attribute kineticEnergy : EnergyValue;
		port shaftInput : MechanicalPort;
		port powerOutput : MechanicalPort;
	}
	
	part def StirlingEngine {
		doc /* Converts thermal energy from a temperature differential into continuous 
		       rotational mechanical work through a closed regenerative thermodynamic cycle. */
		
		attribute hotSideTemp : TemperatureValue;
		attribute coldSideTemp : TemperatureValue;
		attribute workingGasMass : MassValue;
		attribute efficiency : ThermalEfficiency;
		attribute outputPower : PowerValue;
		
		port hotInterface : ThermalPort;
		port coldInterface : ThermalPort;
		port mechanicalOutput : MechanicalPort;
		
		part expansionChamber : ExpansionChamber {
			attribute :>> temperature = hotSideTemp;
		}
		
		part compressionChamber : CompressionChamber {
			attribute :>> temperature = coldSideTemp;
		}
		
		part regenerator : Regenerator;
		part powerPiston : PowerPiston;
		part displacerPiston : DisplacerPiston;
		part crankshaft : Crankshaft;
		part flywheel : Flywheel;
		
		connect hotInterface to expansionChamber.heatInput;
		connect expansionChamber.gasOutput to regenerator.hotSide;
		connect regenerator.coldSide to compressionChamber.gasInput;
		connect compressionChamber.heatOutput to coldInterface;
		connect powerPiston.mechanicalOutput to crankshaft.shaftOutput;
		connect crankshaft.shaftOutput to flywheel.shaftInput;
		connect flywheel.powerOutput to mechanicalOutput;
		
		assert constraint efficiencyCalculation {
			efficiency == 1.0 - (coldSideTemp / hotSideTemp)
		}
	}
	
	part stirlingEngineSystem {
		doc /* Complete Stirling engine system converting heat to mechanical power. */
		
		attribute systemEfficiency : ThermalEfficiency;
		attribute netPowerOutput : PowerValue;
		
		part heatSource : HeatSource;
		part heatSink : HeatSink;
		part engine : StirlingEngine {
			attribute :>> hotSideTemp = heatSource.sourceTemperature;
			attribute :>> coldSideTemp = heatSink.sinkTemperature;
		}
		
		connect heatSource.thermalOutput to engine.hotInterface;
		connect engine.coldInterface to heatSink.thermalInput;
		
		assert constraint powerBalance {
			netPowerOutput == engine.outputPower
		}
	}
	
	action def AbsorbHeat {
		in hotTemp : TemperatureValue;
		in volume : VolumeValue;
		out heatAbsorbed : EnergyValue;
		out expandedPressure : PressureValue;
	}
	
	action def ExpandGas {
		in pressure : PressureValue;
		in volume : VolumeValue;
		out workOutput : EnergyValue;
		out pistonForce : ForceValue;
	}
	
	action def TransferThroughRegenerator {
		in hotGas : ThermalEnergy;
		in regeneratorEfficiency : ThermalEfficiency;
		out cooledGas : ThermalEnergy;
		out storedHeat : EnergyValue;
	}
	
	action def CompressGas {
		in pressure : PressureValue;
		in volume : VolumeValue;
		out workInput : EnergyValue;
	}
	
	action def RejectHeat {
		in coldTemp : TemperatureValue;
		in compressedGas : ThermalEnergy;
		out heatRejected : EnergyValue;
	}
	
	action def ConvertToRotation {
		in linearForce : ForceValue;
		in crankAngle : ISQ::AngleValue;
		out torque : TorqueValue;
	}
	
	action def StirlingCycleOperation {
		doc /* Executes the complete Stirling thermodynamic cycle continuously. */
		
		in heatInput : ThermalEnergy;
		in coldSinkTemp : TemperatureValue;
		out mechanicalWork : MechanicalPower;
		
		first start;
		then merge cycleLoop;
		
		then action absorbHeat : AbsorbHeat {
			in hotTemp = heatInput.temperature;
			in volume : VolumeValue;
			out heatAbsorbed : EnergyValue;
			out expandedPressure : PressureValue;
		}
		
		flow absorbHeat.expandedPressure to expandGas.pressure;
		
		then action expandGas : ExpandGas {
			in pressure : PressureValue;
			in volume : VolumeValue;
			out workOutput : EnergyValue;
			out pistonForce : ForceValue;
		}
		
		flow expandGas.pistonForce to convertToRotation.linearForce;
		
		then action transferHot : TransferThroughRegenerator {
			in hotGas : ThermalEnergy;
			in regeneratorEfficiency : ThermalEfficiency;
			out cooledGas : ThermalEnergy;
			out storedHeat : EnergyValue;
		}
		
		flow transferHot.cooledGas to compressGas.pressure;
		
		then action compressGas : CompressGas {
			in pressure : PressureValue;
			in volume : VolumeValue;
			out workInput : EnergyValue;
		}
		
		then action rejectHeat : RejectHeat {
			in coldTemp = coldSinkTemp;
			in compressedGas : ThermalEnergy;
			out heatRejected : EnergyValue;
		}
		
		then action convertToRotation : ConvertToRotation {
			in linearForce : ForceValue;
			in crankAngle : ISQ::AngleValue;
			out torque : TorqueValue;
		}
		
		flow convertToRotation.torque to mechanicalWork.torque;
		
		then cycleLoop;
	}
	
	state def StirlingCycleStates {
		entry; 
		then isothermalExpansion;
		
		state isothermalExpansion {
			doc /* Hot gas expands at constant temperature, absorbing heat and producing work. */
		}
		
		accept at expansionComplete;
		then constantVolumeHotToCold;
		
		state constantVolumeHotToCold {
			doc /* Gas moves through regenerator from hot to cold side at constant volume. */
		}
		
		accept at transferComplete;
		then isothermalCompression;
		
		state isothermalCompression {
			doc /* Cold gas compressed at constant temperature, rejecting heat. */
		}
		
		accept at compressionComplete;
		then constantVolumeColdToHot;
		
		state constantVolumeColdToHot {
			doc /* Gas moves through regenerator from cold to hot side at constant volume. */
		}
		
		accept at returnComplete;
		then isothermalExpansion;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The Stirling engine system shall convert thermal energy from a heat source 
		       into continuous rotational mechanical power by exploiting a temperature differential. */
		
		subject system : stirlingEngineSystem;
		
		require constraint temperatureDifferential {
			system.heatSource.sourceTemperature > system.heatSink.sinkTemperature
		}
		
		require constraint continuousPower {
			system.engine.mechanicalOutput.mechanicalOutput.power > 0 [W]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The Stirling engine shall achieve thermal efficiency approaching theoretical Carnot limit. */
		
		subject engine : StirlingEngine;
		
		attribute carnotEfficiency : ThermalEfficiency;
		attribute minimumEfficiency : ThermalEfficiency = 0.30;
		
		require constraint efficiencyLimit {
			engine.efficiency <= carnotEfficiency and
			engine.efficiency >= minimumEfficiency
		}
	}
	
	requirement def ContinuousOperationRequirement {
		doc /* The system shall operate continuously as long as temperature differential is maintained. */
		
		subject system : stirlingEngineSystem;
		
		require constraint sustainedOperation {
			system.heatSource.sourceTemperature - system.heatSink.sinkTemperature >= 100 [K]
		}
	}
	
	requirement def PowerOutputRequirement {
		doc /* The system shall deliver smooth rotational power through flywheel stabilization. */
		
		subject engine : StirlingEngine;
		
		attribute minimumPower : PowerValue = 1000 [W];
		
		require constraint adequatePower {
			engine.outputPower >= minimumPower
		}
	}
	
	requirement stirlingEngineSystemRequirements {
		doc /* Top-level requirements for Stirling engine system. */
		
		subject system : stirlingEngineSystem;
		
		require primaryFunction : PrimaryFunctionRequirement;
		require efficiency : EfficiencyRequirement;
		require continuousOperation : ContinuousOperationRequirement;
		require powerOutput : PowerOutputRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import StirlingEngineSystem::*;

    part testSubject : HeatSource {
        exhibit state sm : StirlingCycleStates;
    }

    action orchestrator {
        attribute testHotTemp : TemperatureValue;
        attribute testVolume : VolumeValue;
        action actionProbe : AbsorbHeat {
            in hotTemp = testHotTemp;
            in volume = testVolume;
        }
        first actionProbe;
    }
}
