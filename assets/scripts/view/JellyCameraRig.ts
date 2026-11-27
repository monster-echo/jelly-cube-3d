// Jelly Cube 3D — Smooth 360° Unrestricted Quaternion Orbital Camera Rig

import { _decorator, Camera, Component, Quat, Vec3 } from 'cc';

const { ccclass, property } = _decorator;

const DEFAULT_YAW = 38;
const DEFAULT_PITCH = 28;

function makeInitialQuat(): Quat {
    const qYaw = new Quat();
    const qPitch = new Quat();
    const out = new Quat();
    Quat.fromAxisAngle(qYaw, Vec3.UNIT_Y, (DEFAULT_YAW * Math.PI) / 180);
    Quat.fromAxisAngle(qPitch, Vec3.UNIT_X, (-DEFAULT_PITCH * Math.PI) / 180);
    Quat.multiply(out, qYaw, qPitch);
    return out;
}

@ccclass('JellyCameraRig')
export class JellyCameraRig extends Component {
    @property(Camera)
    camera: Camera | null = null;

    distance = 9.5;

    private _rot = makeInitialQuat();
    private _targetRot = makeInitialQuat();
    private _targetDistance = 9.5;
    private readonly _lookAt = new Vec3(0, -0.1, 0);
    private readonly _tmpRight = new Vec3();
    private readonly _tmpUp = new Vec3();
    private readonly _tmpOffset = new Vec3();
    private readonly _qDelta = new Quat();

    setCubeSize(size: number): void {
        this._targetDistance = (4.6 + size * 2.2) * 1.3;
    }

    orbitBy(deltaX: number, deltaY: number): void {
        // Rotate around the camera's current local up/right axes so 360° tumbling
        // works smoothly in every direction without ±72° pitch lock or gimbal flip.
        const yawRad = (-deltaX * 0.35 * Math.PI) / 180;
        const pitchRad = (-deltaY * 0.32 * Math.PI) / 180;

        Vec3.transformQuat(this._tmpUp, Vec3.UNIT_Y, this._targetRot);
        Quat.fromAxisAngle(this._qDelta, this._tmpUp, yawRad);
        Quat.multiply(this._targetRot, this._qDelta, this._targetRot);

        Vec3.transformQuat(this._tmpRight, Vec3.UNIT_X, this._targetRot);
        Quat.fromAxisAngle(this._qDelta, this._tmpRight, pitchRad);
        Quat.multiply(this._targetRot, this._qDelta, this._targetRot);
        Quat.normalize(this._targetRot, this._targetRot);
    }

    zoomBy(delta: number): void {
        this._targetDistance = Math.max(5.5, Math.min(16, this._targetDistance + delta));
    }

    resetView(size: number): void {
        this._targetRot = makeInitialQuat();
        this.setCubeSize(size);
    }

    update(dt: number): void {
        const lerp = 1 - Math.exp(-14 * dt);
        Quat.slerp(this._rot, this._rot, this._targetRot, lerp);
        this.distance += (this._targetDistance - this.distance) * lerp;

        Vec3.transformQuat(this._tmpOffset, Vec3.UNIT_Z, this._rot);
        this._tmpOffset.multiplyScalar(this.distance);
        this.node.setPosition(
            this._lookAt.x + this._tmpOffset.x,
            this._lookAt.y + this._tmpOffset.y,
            this._lookAt.z + this._tmpOffset.z,
        );

        Vec3.transformQuat(this._tmpUp, Vec3.UNIT_Y, this._rot);
        this.node.lookAt(this._lookAt, this._tmpUp);
    }
}
