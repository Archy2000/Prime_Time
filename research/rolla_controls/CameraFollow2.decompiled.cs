using UnityEngine;

public class CameraFollow2 : MonoBehaviour
{
	public Transform target;

	public float smoothSpeed = 0.125f;

	public Vector3 baseOffset = new Vector3(-10f, 10f, -10f);

	public float minOrthographicSize = 5f;

	public float maxOrthographicSize = 10f;

	public float zoomSmooth = 0.2f;

	private Camera cam;

	private float zoomVelocity;

	private void Start()
	{
		cam = GetComponent<Camera>();
	}

	private void LateUpdate()
	{
		if (!(target == null))
		{
			Vector3 b = target.position + baseOffset;
			transform.position = Vector3.Lerp(transform.position, b, smoothSpeed);
			transform.LookAt(target.position);
			float num = Mathf.Clamp(target.localScale.x, minOrthographicSize, maxOrthographicSize);
			cam.orthographicSize = Mathf.SmoothDamp(cam.orthographicSize, num, ref zoomVelocity, zoomSmooth);
		}
	}
}
