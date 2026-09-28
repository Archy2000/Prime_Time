using UnityEngine;

public class RelativeMovement : MonoBehaviour
{
	public Vector3 direction = Vector3.forward;

	public float speed = 5f;

	private Transform parentTransform;

	private void Start()
	{
		parentTransform = transform.parent;
	}

	private void Update()
	{
		Vector3 vector = parentTransform.TransformDirection(direction);
		transform.position += vector.normalized * speed * Time.deltaTime;
	}
}
