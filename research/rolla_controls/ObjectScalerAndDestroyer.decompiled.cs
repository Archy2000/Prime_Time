using UnityEngine;

public class ObjectScalerAndDestroyer : MonoBehaviour
{
	public float destroyTime = 0.8f;

	public float startScale = 0.5f;

	public float endScale = 1f;

	private float timer;

	private void Update()
	{
		float num = Mathf.Lerp(startScale, endScale, timer / destroyTime);
		transform.localScale = new Vector3(num, num, num);
		timer += Time.deltaTime;
		if (timer >= destroyTime)
		{
			Object.Destroy(gameObject);
		}
	}
}
