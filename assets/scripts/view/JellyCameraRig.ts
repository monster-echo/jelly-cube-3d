// Jelly Cube 3D — Smooth Orbital Camera Rig with Inertia & Zoom

import { _decorator, Camera, Component, Vec3 } from 'cc';

const { ccclass, property } = _decorator;

@ccclass('JellyCameraRig')
export class JellyCameraRig extends Component {
    @property(Camera)
    camera: Camera | null = null;

    yaw = 38;
    pitch = 28;
    distance = 9.5;

    private _targetYaw = 38;
    private _targetPitch = 28;
    private _targetDistance = 9.5;
    private readonly _lookAt = new Vec3(0, -0.1, 0);

    setCubeSize(size: number): void {
        this._targetDistance = (4.6 + size * 2.2) * 1.3;
    }

    orbitBy(deltaX: number, deltaY: number): void {
        this._targetYaw -= deltaX * 0.35;
        this._targetPitch = Math.max(-72, Math.min(72, this._targetPitch + deltaY * 0.32));
    }

    zoomBy(delta: number): void {
        this._targetDistance = Math.max(5.5, Math.min(16, this._targetDistance + delta));
    }

    resetView(size: number): void {
        this._targetYaw = 38;
        this._targetPitch = 28;
        this.setCubeSize(size);
    }

    update(dt: number): void {
        const lerp = 1 - Math.exp(-14 * dt);
        this.yaw += (this._targetYaw - this.yaw) * lerp;
        this.pitch += (this._targetPitch - this.pitch) * lerp;
        this.distance += (this._targetDistance - this.distance) * lerp;

        const yr = (this.yaw * Math.PI) / 180;
        const pr = (this.pitch * Math.PI) / 180;
        const cosP = Math.cos(pr);

        const x = this.distance * cosP * Math.sin(yr);
        const y = this.distance * Math.sin(pr);
        const z = this.distance * cosP * Math.cos(yr);

        this.node.setPosition(x, y, z);
        this.node.lookAt(this._lookAt);
    }
}
