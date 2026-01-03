package EndFaceMechanicalSealSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		alias Pressure for ISQ::PressureValue;
		alias Temperature for ISQ::ThermodynamicTemperatureValue;
		alias AngularVelocity for ISQ::AngularVelocityValue;
		alias Force for ISQ::ForceValue;
		alias Length for ISQ::LengthValue;
		alias VolumeFlowRate for ISQ::VolumeFlowRateValue;
		alias Time for ISQ::TimeValue;
		alias Torque for ISQ::TorqueValue;

		enum def SealStatus {
			enum operational;
			enum degraded;
			enum failed;
		}

		item def ProcessFluid {
			attribute pressure : Pressure;
			attribute temperature : Temperature;
			attribute viscosity : Real;
		}

		item def BarrierFluid {
			attribute pressure : Pressure;
			attribute flowRate : VolumeFlowRate;
			attribute temperature : Temperature;
		}

		port def FluidInletPort {
			in item processFluid : ProcessFluid;
		}

		port def BarrierFluidPort {
			in item barrierFluid : BarrierFluid;
		}

		port def ShaftCouplingPort {
			in attribute rotationalSpeed : AngularVelocity;
			in attribute transmittedTorque : Torque;
		}

		port def LeakagePort {
			out attribute leakageRate : VolumeFlowRate;
		}

		part def StationaryFaceRing {
			attribute material : String;
			attribute surfaceRoughness : Length;
			attribute hardness : Real;
			port sealingInterface;
		}

		part def RotatingFaceRing {
			attribute material : String;
			attribute surfaceRoughness : Length;
			attribute hardness : Real;
			port sealingInterface;
			port shaftConnection : ShaftCouplingPort;
		}

		part def SpringMechanism {
			attribute springConstant : Real;
			attribute preloadForce : Force;
			attribute compressionDistance : Length;
		}

		part def SecondarySealing {
			part oRingStatic;
			part oRingDynamic;
			attribute elastomerMaterial : String;
		}

		part def SealGland {
			attribute housingMaterial : String;
			port fluidChamber : FluidInletPort;
			port barrierChamber : BarrierFluidPort;
		}

		action def ApplyClosingForce {
			in springPreload : Force;
			in hydraulicForce : Force;
			out totalClosingForce : Force;
		}

		action def GenerateHydrodynamicFilm {
			in rotationalSpeed : AngularVelocity;
			in fluidViscosity : Real;
			in closingForce : Force;
			out filmThickness : Length;
		}

		action def ControlLeakage {
			in filmThickness : Length;
			in pressureDifferential : Pressure;
			in faceCondition : Real;
			out leakageRate : VolumeFlowRate;
		}

		action def ManageBarrierPressure {
			in processPressure : Pressure;
			in barrierSupplyPressure : Pressure;
			out effectiveBarrierPressure : Pressure;
		}

		action def MonitorWear {
			in operatingTime : Time;
			in faceTemperature : Temperature;
			in leakageRate : VolumeFlowRate;
			out wearDepth : Length;
			out status : SealStatus;
		}

		action def SealOperation {
			in processFluid : ProcessFluid;
			in barrierFluid : BarrierFluid;
			in shaftSpeed : AngularVelocity;
			out leakageRate : VolumeFlowRate;
			out sealStatus : SealStatus;

			first start;
			then action manageBarrier : ManageBarrierPressure {
				in processPressure = processFluid.pressure;
				in barrierSupplyPressure = barrierFluid.pressure;
				out effectiveBarrierPressure : Pressure;
			}
			then action applyForce : ApplyClosingForce {
				in springPreload : Force = 500.0 [N];
				in hydraulicForce : Force = 200.0 [N];
				out totalClosingForce : Force;
			}
			flow applyForce.totalClosingForce to generateFilm.closingForce;
			then action generateFilm : GenerateHydrodynamicFilm {
				in rotationalSpeed = shaftSpeed;
				in fluidViscosity = processFluid.viscosity;
				in closingForce : Force;
				out filmThickness : Length;
			}
			flow generateFilm.filmThickness to controlLeak.filmThickness;
			then action controlLeak : ControlLeakage {
				in filmThickness : Length;
				in pressureDifferential = processFluid.pressure;
				in faceCondition : Real = 0.95;
				out leakageRate : VolumeFlowRate;
			}
			flow controlLeak.leakageRate to SealOperation::leakageRate;
			then action monitorWear : MonitorWear {
				in operatingTime : Time = 5000.0 [h];
				in faceTemperature = processFluid.temperature;
				in leakageRate = controlLeak.leakageRate;
				out wearDepth : Length;
				out status : SealStatus;
			}
			flow monitorWear.status to SealOperation::sealStatus;
			then done;
		}

		attribute def StartupSignal;
		attribute def ShutdownSignal;

		state def SealLifecycleStateMachine {
			entry; then idle;

			state idle {
				doc /* Seal is installed but not pressurized or rotating. */
			}

			transition idle_to_startup
				first idle
				accept startupSignal : StartupSignal
				then startup;

			state startup {
				doc /* Barrier fluid pressurization and initial shaft rotation. */
				entry; then pressurizing;
				state pressurizing;
				transition pressurizing_to_sealing
					first pressurizing
					if barrierPressure > processPressure
					then sealing;
				state sealing;
			}

			transition startup_to_normalOperation
				first startup
				if filmEstablished
				then normalOperation;

			state normalOperation {
				doc /* Seal operating within design parameters. */
				do action continuousMonitoring;
			}

			transition normalOperation_to_degraded
				first normalOperation
				if leakageIncreased or temperatureHigh
				then degraded;

			state degraded {
				doc /* Seal showing signs of wear but still functional. */
			}

			transition degraded_to_failed
				first degraded
				if excessiveLeakage or catastrophicWear
				then failed;

			transition normalOperation_to_shutdown
				first normalOperation
				accept shutdownSignal : ShutdownSignal
				then shutdown;

			state shutdown {
				doc /* Controlled seal shutdown and depressurization. */
			}

			transition shutdown_to_idle
				first shutdown
				if depressurized
				then idle;

			state failed {
				doc /* Seal has failed and requires replacement. */
			}

			attribute barrierPressure : Pressure;
			attribute processPressure : Pressure;
			attribute filmEstablished : Boolean;
			attribute leakageIncreased : Boolean;
			attribute temperatureHigh : Boolean;
			attribute excessiveLeakage : Boolean;
			attribute catastrophicWear : Boolean;
			attribute depressurized : Boolean;
		}

		requirement def PrimaryContainmentFunction {
			doc /* The end-face mechanical seal shall prevent process fluid leakage 
			     from the pressurized equipment along the rotating shaft interface 
			     by maintaining a controlled fluid film between precision-machined 
			     seal faces under dynamic operating conditions. */

			subject seal : EndFaceMechanicalSeal;

			require constraint {
				seal.leakagePort.leakageRate < 0.0001 [L/min]
			}
		}

		requirement def PressureCapability {
			doc /* The seal shall maintain sealing integrity at process pressures 
			     up to the maximum design pressure. */

			subject seal : EndFaceMechanicalSeal;

			require constraint {
				seal.fluidInlet.processFluid.pressure <= 30.0 [bar]
			}
		}

		requirement def RotationalSpeedCapability {
			doc /* The seal shall operate reliably at shaft rotational speeds 
			     up to the maximum design speed. */

			subject seal : EndFaceMechanicalSeal;

			require constraint {
				seal.shaftCoupling.rotationalSpeed <= 3600.0 [rpm]
			}
		}

		requirement def BarrierFluidPressureMargin {
			doc /* The barrier fluid pressure shall exceed process fluid pressure 
			     by a minimum margin to ensure proper seal face lubrication. */

			subject seal : EndFaceMechanicalSeal;

			require constraint {
				seal.barrierFluidInlet.barrierFluid.pressure >= 
					seal.fluidInlet.processFluid.pressure + 2.0 [bar]
			}
		}

		requirement def OperationalLife {
			doc /* The seal shall provide reliable operation for a minimum 
			     service life under normal operating conditions. */

			subject seal : EndFaceMechanicalSeal;

			require constraint {
				seal.operatingHours >= 10000.0 [h]
			}
		}

		part def EndFaceMechanicalSeal {
			doc /* An end-face mechanical seal is a precision sealing device that prevents 
			     process fluid leakage along a rotating shaft by maintaining a controlled 
			     interface between two flat, highly-polished faces - one rotating with the 
			     shaft and one stationary with the equipment housing. The seal operates by 
			     creating a thin hydrodynamic fluid film between the faces through shaft 
			     rotation, balanced by spring and hydraulic closing forces. A barrier fluid 
			     system provides lubrication and cooling while maintaining pressure above 
			     the process fluid to prevent contamination. This configuration enables 
			     reliable sealing in pumps, compressors, and other rotating equipment 
			     handling hazardous or valuable fluids. */

			attribute operatingHours : Time;
			attribute faceTemperature : Temperature;

			port fluidInlet : FluidInletPort;
			port barrierFluidInlet : BarrierFluidPort;
			port shaftCoupling : ShaftCouplingPort;
			port leakagePort : LeakagePort;

			part stationaryFace : StationaryFaceRing {
				attribute :>> material = "Silicon Carbide";
				attribute :>> surfaceRoughness = 0.15 [um];
				attribute :>> hardness = 2500.0;
			}

			part rotatingFace : RotatingFaceRing {
				attribute :>> material = "Carbon Graphite";
				attribute :>> surfaceRoughness = 0.15 [um];
				attribute :>> hardness = 1800.0;
			}

			part springAssembly : SpringMechanism {
				attribute :>> springConstant = 50.0;
				attribute :>> preloadForce = 500.0 [N];
				attribute :>> compressionDistance = 10.0 [mm];
			}

			part secondarySeals : SecondarySealing {
				attribute :>> elastomerMaterial = "Fluoroelastomer (FKM)";
			}

			part gland : SealGland {
				attribute :>> housingMaterial = "Stainless Steel 316";
			}

			connection shaftToRotatingFace 
				connect shaftCoupling to rotatingFace.shaftConnection;

			connection processFluidToGland 
				connect fluidInlet to gland.fluidChamber;

			connection barrierFluidToGland 
				connect barrierFluidInlet to gland.barrierChamber;

			perform action operate : SealOperation {
				in processFluid = fluidInlet.processFluid;
				in barrierFluid = barrierFluidInlet.barrierFluid;
				in shaftSpeed = shaftCoupling.rotationalSpeed;
				out leakageRate : VolumeFlowRate;
				out sealStatus : SealStatus;
			}

			exhibit state lifecycle : SealLifecycleStateMachine;
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement endFaceSealSystemRequirements {
			doc /* The end-face mechanical seal system shall provide reliable 
			     containment of process fluids in rotating equipment by maintaining 
			     a controlled sealing interface between precision-machined faces 
			     under dynamic operating conditions with barrier fluid support. */

			subject sealSystem : EndFaceMechanicalSeal;

			require primaryFunction : PrimaryContainmentFunction;
			require pressureCapability : PressureCapability;
			require speedCapability : RotationalSpeedCapability;
			require barrierPressure : BarrierFluidPressureMargin;
			require serviceLife : OperationalLife;
		}
	}

	package SystemImplementation {
		private import Definitions::*;
		private import Requirements::*;

		part centrifugalPumpSeal : EndFaceMechanicalSeal {
			doc /* End-face mechanical seal assembly for high-pressure centrifugal pump 
			     application in chemical processing service. Primary function: Create and 
			     maintain a dynamic seal between the rotating pump shaft and stationary 
			     housing to prevent hazardous process fluid leakage while accommodating 
			     continuous rotation, pressure differentials, thermal expansion, and 
			     minor shaft misalignment through precision face contact and barrier 
			     fluid lubrication. */

			attribute :>> operatingHours = 12500.0 [h];
			attribute :>> faceTemperature = 95.0 [degC];

			part :>> stationaryFace {
				attribute :>> material = "Reaction Bonded Silicon Carbide";
				attribute :>> surfaceRoughness = 0.10 [um];
				attribute :>> hardness = 2800.0;
			}

			part :>> rotatingFace {
				attribute :>> material = "Resin Impregnated Carbon";
				attribute :>> surfaceRoughness = 0.12 [um];
				attribute :>> hardness = 1900.0;
			}

			part :>> springAssembly {
				attribute :>> springConstant = 55.0;
				attribute :>> preloadForce = 550.0 [N];
				attribute :>> compressionDistance = 12.0 [mm];
			}

			satisfy endFaceSealSystemRequirements;
		}
	}
}
